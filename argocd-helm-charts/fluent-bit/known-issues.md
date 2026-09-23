# Known Issues in Fluent Bit

## Fluent Bit Unable to send logs

```
[2025/04/11 06:56:52] [ warn] [net] getaddrinfo(host='graylog-input.example.com.', err=12): Timeout while contacting DNS servers
```

Verify if the DNS is correct and reachable from your machine for the output of fluent bit

```
faizan@ThinkPad:~$ dig +short graylog-input.example.com
10.2.119.118
10.2.78.221
10.2.39.178
```

Verify if the graylog port is open and reachable from your machine. Connect to the VPN if
graylog is running in an internal private network.

```
faizan@ThinkPad:~$ nc -zv graylog-input.example.com 5555
Connection to graylog-input.example.com (10.2.78.221) 5555 port [tcp/*] succeeded!
```

Create a test ubuntu pod in the same namespace and try the `dig` and `netcat` command above from inside the pod.

If the DNS is not resolved, or the netcat times out, check if there are any network policies blocking the fluent-bit pod.
The default netpol should at least allow the UDP on port 53 for DNS lookup, and the TCP on graylog port(5555 in this case).

Despite this, if the fluent bit pods cannot do the DNS lookup, then try restarting one of the pods.
This is sometimes necessary, as the CNI pods (Calico, Cilium, etc) handle the network connections to the graylog target.

To debug from inside the pod, you will need to change the image of fluent bit to `-debug`, as the default image does not support
an interactive shell. Add -debug to the end of the image, like `fluent/fluent-bit:4.0-debug`.
Then you should be able to see if the pod can connect to the target graylog.

## Logs arrive with no namespace or container labels

Some pods' logs reach the log destination as a single unlabelled stream. A query that
filters on pod metadata returns nothing, even though the container is clearly logging
and the fluent-bit pod on that node is healthy and shipping everything else.

The fluent-bit log shows this repeating:

```
[warn] [http_client] cannot increase buffer: current=32000 requested=64768 max=32000
```

A raw CRI log line carries only a timestamp, a stream and the message. To attach
`namespace_name`, `container_name` and friends, the Kubernetes filter fetches that
pod's object from the API server over HTTP. `Buffer_Size` caps the size of that
response. It has nothing to do with the size of the log line.

The default is 32K, which is smaller than a pod with a few containers and long env
blocks. When the response does not fit, the filter discards all of it rather than
truncating, and the record continues down the pipeline with no metadata at all. The
log line is still shipped and still stored, it just lands in an unlabelled stream
where no query on pod metadata can reach it. Pods with many containers are the usual
offenders, as are CNI agents.

Confirm by measuring the object the filter is trying to read:

```
kubectl get --raw /api/v1/namespaces/<namespace>/pods/<pod> | wc -c
```

Anything over 32000 is affected. This chart sets `Buffer_Size 2M`, above the ~1.5MB
ceiling Kubernetes puts on a single object, so nothing can exceed it. If you have
overridden `config.filters`, note that it is a string and replaces the block wholesale,
so the setting has to be repeated in the override.

The setting only applies to newly tailed files. Lines already shipped stay unlabelled,
and fluent-bit has to restart for the change to take effect.

## OOMKilled while the output is down

If Loki (or any output) is down for a while, fluent-bit pods get `OOMKilled` over and
over, and `KubeDaemonSetRolloutStuck` fires. The log is full of:

```
[error] [output:loki:loki.0] could not flush records to ... HTTP status=500
[ warn] [engine] failed to flush chunk '...', retry in 455 seconds
```

With memory buffering, every chunk waiting for a retry is held in memory. `Mem_Buf_Limit`
only counts the log data, not the overhead per retry, and with `Flush 1` the chunks are
small, so there can be thousands of them. In one case the buffer sat at 95MB while the pods
hit 512Mi. Every OOM also throws away what was buffered.

Check `fluentbit_storage_mem_chunks` (thousands) and `fluentbit_input_storage_memory_bytes`
(stuck at `Mem_Buf_Limit`) in Prometheus.

Raising the memory limit only delays it. This chart uses `storage.type filesystem`, so
most chunks wait on disk under `/var/log/flb-storage/` and survive a restart. If you
override `config.service` or `config.inputs`, keep the `storage.*` lines. Set
`storage.total_limit_size` on your output so the buffer can't fill the node disk.

See [Buffering](https://docs.fluentbit.io/manual/data-pipeline/buffering).
