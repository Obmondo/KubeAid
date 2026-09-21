    #!/bin/sh
    # Updates each workers config to fix hostname
    cp /ossec.conf /wazuh-config-mount/etc/ossec.conf
    node_index=${HOSTNAME##*-}
    sed -i "s/___INDEX___/$node_index/g" /wazuh-config-mount/etc/ossec.conf
