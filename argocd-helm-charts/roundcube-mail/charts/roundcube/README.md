# Roundcube Helm Chart

This Helm chart allows for an easy install of [Roundcube webmail client](https://roundcube.net/) to your Kubernetes cluster.

## Installation

### Add Helm Repository

```
helm repo add mlohr https://helm-charts.mlohr.com/
helm repo update
```

### Create Minimal Configuration

In order to get Roundcube running, you need to provide the following minimal configuration.
For a full documentation of all possible configuration options, check the [values.yaml file](https://gitlab.com/MatthiasLohr/roundcube-helm-chart/-/blob/main/values.yaml).

Your `values.yaml`:
```yaml
ingress:
  host: roundcube.your.domain

imap:
  host: imap.your.domain

smtp:
  host: smtp.your.domain

externalDatabase:
  type: pgsql
  host: db.your.domain
  name: roundcube
  user: roundcube
  password: S3cret!
```


### Install to Kubernetes

```bash
helm install roundcube mlohr/roundcube -f values.yaml
```


## Links
  * https://roundcube.net/
  * https://github.com/roundcube/roundcubemail
  * https://github.com/roundcube/roundcubemail-docker


## License (GPLv3)

Roundcube Helm Chart - Copyright (C) 2021 [Matthias Lohr](https://mlohr.com/) &lt;[mail@mlohr.com](mailto:mail@mlohr.com)&gt;

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
