#!/bin/bash

[[ -z "${1}" ]] || [[ -z "${2}" ]] && echo "Usage: ${0} route-table-id1 route-table-id2" && exit 1

RTID1=${1}
RTID2=${2}

[[ "${RTID1}" == "${RTID2}" ]] && echo "Very funny -- Try giving me two different route tables." && exit 1

VPCID1=$(aws ec2 describe-route-tables --output text --query 'RouteTables[].VpcId' --route-table-ids ${RTID1})
[[ -z "${VPCID1}" ]] && echo "Could not determine VPC for ${RTID1} -- Bad route table ID?" && exit 1
VPCID2=$(aws ec2 describe-route-tables --output text --query 'RouteTables[].VpcId' --route-table-ids ${RTID2})
[[ -z "${VPCID2}" ]] && echo "Could not determine VPC for ${RTID2} -- Bad route table ID?" && exit 1

[[ "${VPCID1}" != "${VPCID2}" ]] && echo "Route tables ${RTID1} and ${RTID2} are in different VPCs -- Not going to compare." && exit 1

# We'll cheat and use mktemp along with diff
OUT1=`mktemp`
OUT2=`mktemp`
aws ec2 describe-route-tables \
    --output text \
    --query 'RouteTables[].Routes[].[GatewayId,NatGatewayId,VpcPeeringConnectionId,DestinationCidrBlock]' \
    --route-table-ids ${RTID1} | awk '{print $1,$2,$3,$4}' | sort >> ${OUT1}
aws ec2 describe-route-tables \
    --output text \
    --query 'RouteTables[].Routes[].[GatewayId,NatGatewayId,VpcPeeringConnectionId,DestinationCidrBlock]' \
    --route-table-ids ${RTID2} | awk '{print $1,$2,$3,$4}' | sort >> ${OUT2}
echo "Comparing ${RTID1} (${OUT1}) with ${RTID2} (${OUT2})"
diff -u0 ${OUT1} ${OUT2}
RC=$?
if [[ $RC -ne 0 ]]; then
    echo "Route tables ${RTID1} and ${RTID2} differ"
else
    echo "Route tables ${RTID1} and ${RTID2} have identical routes"
fi
rm ${OUT1} ${OUT2}
exit ${RC}
