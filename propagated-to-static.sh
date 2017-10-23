#!/bin/bash

[[ -z "${1}" ]] && echo "Usage: ${0} route-table-id" && exit 1

RTID=${1}
VPCID=$(aws ec2 describe-route-tables --output text --query 'RouteTables[].VpcId' --route-table-ids ${RTID})
[[ -z "${VPCID}" ]] && echo "Could not determine VPC -- Bad route table ID?" && exit 1

IFS="
"
declare -a ROUTES=()
declare -A VGWS=()
declare -a VPCE=()
SAWPROP=0

for I in `aws ec2 describe-route-tables \
      	      --output text \
      	      --query 'RouteTables[].Routes[].[GatewayId,NatGatewayId,VpcPeeringConnectionId,DestinationCidrBlock,Origin]' \
	      --route-table-ids ${RTID} | awk '{print $1,$2,$3,$4,$5}'`; do     
    # Could have done an: awk '{print "GATEWAY="$1,"DESTINATION="$2,"ORIGIN="$3[..]}'
    # followed by an eval(), but now we're trusting the output being passed to eval..
    #
    # There's probably a better pure-bash way to pick through the list, but this works for me at the moment.
    GATEWAY=${I%% *}
    REST=${I#* }
    NATGATEWAY=${REST%% *}
    REST=${REST#* }
    VPCPEER=${REST%% *}
    REST=${REST#* }
    DESTINATION=${REST%% *}
    ORIGIN=${REST##* }
    echo "#DEBUG Processing entry: GATEWAY=${GATEWAY}, NATGATEWAY=${NATGATEWAY}, VPCPEER=${VPCPEER}, DESTINATION=${DESTINATION}, ORIGIN=${ORIGIN}"

    # Probably not needed, but...
    if [[ "${GATEWAY}" =~ 'vgw' ]]; then
	VGWS["${GATEWAY}"]='aws ec2 disable-vgw-route-propagation --gateway-id '${GATEWAY}' --route-table-id ${NEWRTID}'
    fi

    if [[ "${GATEWAY}" != "local" ]]; then
	if [[ "${GATEWAY}" =~ 'vpce' ]]; then
	    VPCE+=('aws ec2 modify-vpc-endpoint --add-route-table-ids ${NEWRTID} --vpc-endpoint-id '$GATEWAY)
	elif [[ "${GATEWAY}" == "None" ]] && [[ "${NATGATEWAY}" != "None" ]]; then
	    ROUTES+=('aws ec2 create-route --destination-cidr-block '${DESTINATION}' --gateway-id '${NATGATEWAY}' --route-table-id ${NEWRTID}')
	elif [[ "${VPCPEER}" != "None" ]]; then
	    ROUTES+=('aws ec2 create-route --destination-cidr-block '${DESTINATION}' --route-table-id ${NEWRTID} --vpc-peering-connection-id '${VPCPEER})
	elif [[ "${GATEWAY}" != "None" ]]; then
	    case "${ORIGIN}" in
		'CreateRoute')
		    ROUTES+=('aws ec2 create-route --destination-cidr-block '${DESTINATION}' --gateway-id '${GATEWAY}' --route-table-id ${NEWRTID}')
		    ;;
		'EnableVgwRoutePropagation')
		    ROUTES+=('aws ec2 create-route --destination-cidr-block '${DESTINATION}' --gateway-id '$GATEWAY' --route-table-id ${NEWRTID}')
		    SAWPROP=1
		    ;;
		*)
		    echo "UNKNOWN ORIGIN: ${ORIGIN}"
		    exit 1
		    ;;
	    esac
	else
	    echo "UNKNOWN TYPE/GATEWAY"
	    exit 1
	fi
    fi
done

if [[ ${SAWPROP} -eq 0 ]]; then
    echo ""
    echo "WARNING: Did not see *any* routes that appeared to originate from VGW Route Propagation"
    echo "Executing the commands that follow may essentially be a NOP"
    echo ""
    sleep 10
fi

echo ""
echo "----------------------------------------------------------------------------"
echo "Run the following commands to re-create ${RTID} with non-propagated routes"
echo "No tags will be created -- Add those manually via:"
echo "  aws ec2 create-tags --resources \${NEWRTID} --tags [..]"
echo "----------------------------------------------------------------------------"
echo ""
echo "export NEWRTID=\$(aws ec2 create-route-table --output text --query 'RouteTable.RouteTableId' --vpc-id ${VPCID})"

# Could have used printf()s
for I in "${VGWS[@]}"; do
    echo ${I}
done

for I in "${ROUTES[@]}"; do
    echo ${I}
done

for I in "${VPCE[@]}"; do
    echo ${I}
done
