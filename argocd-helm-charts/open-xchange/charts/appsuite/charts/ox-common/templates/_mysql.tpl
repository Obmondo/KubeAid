{{/*
These functions deal with mysql settings. Settings are: 

host - the hostname of the database
database - the database/schema to connect to
user - the username to use to authenticate to the database
password - the password to use for authenticating to the database

In case a primary/replica setup is supported by the application, these settings
can be set individually for the write and read database connections. In case no 
primary/replica setup is explicitely supported, only the write connection is used. 

The input datastructure for all the methods is the same. 

For primary/replica: 

mysql:
    writeHost: ""
    writePort: ""
    writeDatabase: ""
    
    readHost: ""
    readPort: ""
    readDatabase: ""

    existingSecret: ""
    auth:
        writeUser: ""
        writePassword: ""

        readUser: ""
        readPassword: ""

The read connection settings default to the "write" settings, so if, for example, only the host differs for the two, 
you can also write: 

mysql:
    writeHost: ""
    writePort: ""
    writeDatabase: ""

    readHost: ""

    existingSecret: ""
    auth:
        writeUser: ""
        writePassword: ""

or, to make it even clearer, the write attributes also default to non-specific attributes
without a prefix. So the above can be written as: 

mysql:
    writeHost: ""
    writePort: ""
    readHost: ""

    database: ""

    existingSecret: ""
    auth:
        user: ""
        password: ""


For a single db connection, use unprefixed attributes for everything: 

mysql:
    host: ""
    port: ""
    database: ""

    existingSecret: ""
    auth:
        user: ""
        password: ""


To select the correct values, use the templates defined below. 

If your application supports a primary/replica setup, use, e.g.: 

data: 
    MYSQL_WRITE_HOST: {{ include "ox-common.mysql.writeHost" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_WRITE_PORT: {{ include "ox-common.mysql.writePort" (dict "mysql" .Values.mysql "context" .) | quote }}
    MYSQL_WRITE_DATABASE: {{ include "ox-common.mysql.writeDatabase" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_WRITE_USER: {{ include "ox-common.mysql.writeUser" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_WRITE_PASSWORD: {{ include "ox-common.mysql.writePassword" (dict "mysql" .Values.mysql "context" .) }}

    MYSQL_READ_HOST: {{ include "ox-common.mysql.readHost" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_READ_PORT: {{ include "ox-common.mysql.readPort" (dict "mysql" .Values.mysql "context" .) | quote }}
    MYSQL_READ_DATABASE: {{ include "ox-common.mysql.readDatabase" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_READ_USER: {{ include "ox-common.mysql.readUser" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_READ_PASSWORD: {{ include "ox-common.mysql.readPassword" (dict "mysql" .Values.mysql "context" .) }}

Note that its better to store user and password in a secret and use that to populate
the environment variable

Note also, that for the port number to work in this way you'll usually want to slap a `| quote` in the end so the yaml parser doesn't 
parse the port number as a number 

If your application supports only one database connection for both reading and writing,
use the generic forms: 


data: 
    MYSQL_HOST: {{ include "ox-common.mysql.host" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_PORT: {{ include "ox-common.mysql.port" (dict "mysql" .Values.mysql "context" .) | quote  }}
    MYSQL_DATABASE: {{ include "ox-common.mysql.database" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_USER: {{ include "ox-common.mysql.user" (dict "mysql" .Values.mysql "context" .) }}
    MYSQL_PASSWORD: {{ include "ox-common.mysql.password" (dict "mysql" .Values.mysql "context" .) }}

In any case, your chart will support any of the input datastructures from above

*/}}
{{- define "ox-common.mysql.host" -}}
{{ (include "ox-common.mysql.writeHost" . ) }}
{{- end -}}

{{- define "ox-common.mysql.writeHost" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{- $result = .mysql.writeHost | default .mysql.host | default $globalMysql.writeHost | default $globalMysql.host -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{- $result = .mysql.writeHost | default .mysql.host | default "" -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.readHost" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{ $result = .mysql.readHost | default .mysql.host | default .mysql.writeHost | default $globalMysql.readHost | default $globalMysql.host | default $globalMysql.writeHost }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{ $result = .mysql.readHost | default .mysql.host | default .mysql.writeHost }}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.port" -}}
{{ (include "ox-common.mysql.writePort" . ) }}
{{- end -}}

{{- define "ox-common.mysql.writePort" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{- $result = .mysql.writePort | default .mysql.port | default $globalMysql.writePort | default $globalMysql.port | default 3306 -}}
{{- $result = toString $result -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" $result -}}
{{- $result = .mysql.writePort | default .mysql.port | default 3306 -}}
{{- $result = toString $result -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.readPort" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{ $result = .mysql.readPort | default .mysql.port | default .mysql.writePort | default $globalMysql.readPort | default $globalMysql.port | default $globalMysql.writePort | default 3306 }}
{{- $result = toString $result -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" $result -}}
{{ $result = .mysql.readPort | default .mysql.port | default .mysql.writePort | default 3306 }}
{{- $result = toString $result -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.database" -}}
{{ (include "ox-common.mysql.writeDatabase" . ) }}
{{- end -}}

{{- define "ox-common.mysql.writeDatabase" -}}
{{- $result := "" -}}
{{- if (.mysql).writeDatabase }}
{{- $result = .mysql.writeDatabase -}}
{{- end -}}
{{- if (.mysql).database }}
{{- $result = $result | default .mysql.database -}}
{{- end -}}
{{- if ((.context).Values.global).mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{- if $globalMysql.writeDatabase -}}
{{- $result = $result | default $globalMysql.writeDatabase -}}
{{- end -}}
{{- if $globalMysql.database -}}
{{- $result = $result | default $globalMysql.database -}}
{{- end -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.readDatabase" -}}
{{- $result := "" -}}
{{- if (.mysql).readDatabase }}
{{- $result = .mysql.readDatabase -}}
{{- end -}}
{{- if (.mysql).database }}
{{- $result = $result | default .mysql.database -}}
{{- end -}}
{{- if (.mysql).writeDatabase }}
{{- $result = $result | default .mysql.writeDatabase -}}
{{- end -}}
{{- if ((.context).Values.global).mysql -}}
{{- $globalMysql := .context.Values.global.mysql -}}
{{- if $globalMysql.readDatabase -}}
{{- $result = $result | default $globalMysql.readDatabase -}}
{{- end -}}
{{- if $globalMysql.database -}}
{{- $result = $result | default $globalMysql.database -}}
{{- end -}}
{{- if $globalMysql.writeDatabase -}}
{{- $result = $result | default $globalMysql.writeDatabase -}}
{{- end -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.user" -}}
{{ (include "ox-common.mysql.writeUser" . ) }}
{{- end -}}

{{- define "ox-common.mysql.writeUser" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- if .context.Values.global.mysql.auth -}}
{{- $globalAuth := .context.Values.global.mysql.auth -}}
{{- $localAuth := dict -}}
{{- if .mysql.auth -}}
{{- $localAuth = .mysql.auth -}}
{{- end -}}
{{- $result = $localAuth.writeUser | default $localAuth.user | default $globalAuth.writeUser | default $globalAuth.user -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{- $result = .mysql.auth.writeUser | default .mysql.auth.user | default "" -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.readUser" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- if .context.Values.global.mysql.auth -}}
{{- $globalAuth := .context.Values.global.mysql.auth -}}
{{- $localAuth := dict -}}
{{- if .mysql.auth -}}
{{- $localAuth = .mysql.auth -}}
{{- end -}}
{{- $result = $localAuth.readUser | default $localAuth.user | default $localAuth.writeUser | default $globalAuth.readUser | default $globalAuth.user | default $globalAuth.writeUser -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{- $result = .mysql.auth.readUser | default (include "ox-common.mysql.writeUser" . ) -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.password" -}}
{{ (include "ox-common.mysql.writePassword" . ) }}
{{- end -}}

{{- define "ox-common.mysql.writePassword" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- if .context.Values.global.mysql.auth -}}
{{- $globalAuth := .context.Values.global.mysql.auth -}}
{{- $localAuth := dict -}}
{{- if .mysql.auth -}}
{{- $localAuth = .mysql.auth -}}
{{- end -}}
{{- $result = $localAuth.writePassword | default $localAuth.password | default $globalAuth.writePassword | default $globalAuth.password -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{- $result = .mysql.auth.writePassword | default .mysql.auth.password | default "" -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{- define "ox-common.mysql.readPassword" -}}
{{- $result := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- if .context.Values.global.mysql.auth -}}
{{- $globalAuth := .context.Values.global.mysql.auth -}}
{{- $localAuth := dict -}}
{{- if .mysql.auth -}}
{{- $localAuth = .mysql.auth -}}
{{- end -}}
{{- $result = $localAuth.readPassword | default $localAuth.password | default $localAuth.writePassword | default $globalAuth.readPassword | default $globalAuth.password | default $globalAuth.writePassword -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if eq "" ($result | toString) -}}
{{- $result = .mysql.auth.readPassword | default (include "ox-common.mysql.writePassword" . ) -}}
{{- end -}}
{{ $result }}
{{- end -}}

{{/*
Return true if a secret object should be created for MySQL
*/}}
{{- define "ox-common.mysql.createSecret" -}}
{{- $globalSecret := (include "ox-common.mysql.existingSecret.global" .) -}}
{{- $localSecret := (include "ox-common.mysql.existingSecret.local" .) -}}
{{- $result := (coalesce $globalSecret $localSecret) -}}
{{- if $result -}}
{{- false -}}
{{- else -}}
{{- true -}}
{{- end -}}
{{- end -}}

{{/*
Gets the local existingSecret
*/}}
{{- define "ox-common.mysql.existingSecret.local" -}}
{{- if .mysql -}}
{{- if .mysql.existingSecret -}}
{{- .mysql.existingSecret -}}
{{- end -}}  
{{- end -}}
{{- end -}}

{{/*
Gets the global existingSecret
*/}}
{{- define "ox-common.mysql.existingSecret.global" -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- if .context.Values.global.mysql.existingSecret -}}
{{- .context.Values.global.mysql.existingSecret -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Return the MySQL secret name
*/}}
{{- define "ox-common.mysql.secretName" -}}
{{- $secretName := "" -}}
{{- if .context -}}
{{- if .context.Values.global -}}
{{- if .context.Values.global.mysql -}}
{{- $secretName = .context.Values.global.mysql.existingSecret -}}
{{- end -}}
{{- end -}}
{{- end -}}
{{- if not $secretName -}}
{{- if .mysql -}}
{{- $secretName = .mysql.existingSecret -}}
{{- end -}}
{{- end -}}
{{- if not $secretName -}}
{{- $secretName = printf "%s-%s" (include "ox-common.names.fullname" .context ) "mysql" -}}
{{- end -}}
{{- if not $secretName -}}
{{- fail "Unable to determine secret name" -}}
{{- end -}}
{{- $secretName -}}
{{- end -}}
