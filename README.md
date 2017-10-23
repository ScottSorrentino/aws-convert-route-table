# AWS Route Table Conversion

This is a set of quickie `bash` scripts to assist in converting an AWS VPC route table from VGW-propagated to static route entries.

# Why?

At $DAYJOB, we're converting people from VPN-based VGWs to using Direct Connect.  As part of that migration, some folks had manually nailed in "static" routes on their VPN configuration and had enabled route propagation on the associated route tables.  As we move to Direct Connect, our Networking team would prefer to avoid creating a multitude of different configurations for each customer.

As long as our local network is advertising a full list of routes to AWS, individuals can pick-and-choose hosts/networks and shove them back down the Direct Connect by adding static route table entries.  These tools assist in that preparation effort.

# Conversion Helper

The script `propagated-to-static.sh` uses the AWS CLI utilities and expects you to have credentials configured (IAM Role, Access Key, STS, etc).  You hand it an existing route table ID and it spits out a list of CLI commands for you to create and populate a new route table.  The new table has propagation disabled and the tool will warn you if it appears this effort is a no-op (ie: no propagated routes in the existing table).

Usage: `propagated-to-static.sh route-table-id`

This tool currently supports picking up IGW/NAT GW, VPC peering connections, VPC endpoints and manual/static route entries with a gateway defined.

Note that tags are **not copied**, nor are any subnet associations changed!  After giving the new route table once-over, feel free to tag and/or associate as needed.

# Route Table Diff

There is another helper script, `diff-route-tables.sh`, that uses the same AWS CLI utilities and permissions to look for differences between two route tables.  It does a little bit of sanity checking to make sure both route tables are associated with the same VPC.  Ideally, one might run this tool prior to making any subnet route table association changes.

Usage: `diff-route-tables.sh route-table-id1 route-table-id2`

