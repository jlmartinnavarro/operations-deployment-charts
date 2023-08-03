{{ define "mw.rsyslog.omkafka_action" }}
action(type="omkafka"
        broker=[{{ range $idx, $el := .Values.mw.logging.kafka_brokers }}{{ if $idx }},{{ end }}"{{ $el.host }}:{{ $el.port }}"{{ end }}]
        topic="{{ .topic }}"
        dynatopic="on"
        dynatopic.cachesize="1000"
        partitions.auto="on"
        template="{{ .template | default "syslog_cee" }}"
        queue.type="LinkedList" queue.size="10000" queue.filename="{{ .name }}"
        queue.highWatermark="7000" queue.lowWatermark="6000"
        queue.checkpointInterval="5"
        confParam=[ "security.protocol=ssl",
                    "ssl.ca.location={{ .Values.mw.logging.ca_cert_path }}",
                    "compression.codec=snappy",
                    "socket.timeout.ms=60000",
                    "socket.keepalive.enable=true",
                    "queue.buffering.max.ms=50",
                    "batch.num.messages=1000" ]
)
{{ end }}
{{ define "mw.rsyslog.application" }}
module(load="imfile")
module(load="mmjsonparse")
module(load="omkafka")
module(load="mmnormalize")
# Apache access logs
# These logs are received via udp
template(name="access-log-topic" type="string" string="mediawiki.httpd.accesslog")
ruleset(name="accesslog_to_kafka") {
  action(type="mmjsonparse" name="mmjsonparse_accesslog" cookie="")
  {{- dict "Values" .Values "name" "accesslog" "topic" "access-log-topic" "template" "ecs_1110_k8s" | include "mw.rsyslog.omkafka_action" | indent 2 }}
}
input(type="imudp" port="10200" address="{{ .Values.mw.logging.allowed_address }}" ruleset="accesslog_to_kafka")

# PHP-FPM slowlogs
# Slowlogs are sent to a specialized topic, mediawiki.php-fpm.slowlog
template(name="php-slowlog-topic" type="string" string="mediawiki.php-fpm.slowlog")
ruleset(name="slowlog_to_kafka") {
  action(type="mmnormalize" rulebase="/etc/rsyslog.d/php-slowlog.rb")
  {{- dict "Values" .Values "name" "slowlog" "topic" "php-slowlog-topic" "template" "slowlog" | include "mw.rsyslog.omkafka_action" | indent 2 }}
{{- if .Values.mw.logging.debug }}
  action(type="omfile" file="/var/log/php-fpm/slowlog-debug.log" template="unparsed")
{{- end }}
}
# In theory, rsyslog should be able to read this file using 'readMode=1', which allows to read paragraphs.
# But, sadly, php-fpm writes the blank line *before* the stack trace, making imfile unable to read from such file
# So we move to use startmgs.regex to match the blank line. This OTOH means we only log when the next message arrives
# (as we know a log message has finished only once the next one starts)
# This also means that the raw message now encodes newlines as "\\n" and not "#012" as it did with readMode=1
input(
  type="imfile"
  file="/var/log/php-fpm/slowlog.log"
  tag="php-fpm-slowlog"
  startmsg.regex="^$"
  ruleset="slowlog_to_kafka"
)

# PHP-FPM logs
template(name="php-fpm-topic" type="string" string="rsyslog-%syslogseverity-text::lowercase%")
ruleset(name="errorlog_to_kafka") {
  action(type="mmnormalize" rulebase="/etc/rsyslog.d/php-errorlog.rb")
  {{- dict "Values" .Values "name" "errorlog" "topic" "php-fpm-topic" | include "mw.rsyslog.omkafka_action" | indent 2 }}
{{- if .Values.mw.logging.debug }}
  action(type="omfile" file="/var/log/php-fpm/errorlog-debug.log" template="unparsed")
{{- end }}
}
input(type="imfile" addMetadata="on" file="/var/log/php-fpm/error.log" tag="php-fpm-error" ruleset="errorlog_to_kafka")


## Logs generated by MediaWiki and php-wmerrors (via php-fatal-error.php)
# Provide a UDP syslog input to accept JSON payloads (in the syslog message) and forwards them to
# Kakfa.
# To be recognized as JSON the syslog message must be prepended with "@cee: "
# see also https://www.rsyslog.com/doc/v8-stable/configuration/modules/mmjsonparse.html
# Kafka topic selection is based on the syslog message severity.
template(name="udp_localhost_topic" type="string" string="udp_localhost-%syslogseverity-text:::lowercase%")

# Use a separate (in memory) queue to limit message processing to this ruleset only.
ruleset(name="udp_localhost_to_kafka" queue.type="LinkedList") {
  action(type="mmjsonparse" name="mmjsonparse_udp_localhost")
  {{- dict "Values" .Values "name" "udp_localhost_compat" "topic" "udp_localhost_topic" | include "mw.rsyslog.omkafka_action" | indent 2 }}
}

input(type="imudp" port="10514" address="{{ .Values.mw.logging.allowed_address }}" ruleset="udp_localhost_to_kafka")
# For messages generated by php-wmerrors, also ship them to udp2log
# Emulate MediaWiki's wfDebugLog / wfErrorLog format
template(name="MediaWiki" type="string" string="%programname% %timegenerated% %HOSTNAME%: %msg%\n")
if ($programname startswith 'php7.')  then {
    @{{ .Values.mw.logging.udp2log_hostport }};MediaWiki
}
{{ end -}}
{{- define "mw.rsyslog.annotations" -}}
{{- if .Values.mw.logging.rsyslog }}
{{ $tpl := .Files.Get "rsyslog/templates.conf" }}
checksum/rsyslog: {{ include "mw.rsyslog.application" . | printf "%s%s" $tpl | sha256sum }}
{{- end }}
{{- end -}}
{{/*
  Write the configmap out
*/}}
{{- if .Values.mw.logging.rsyslog }}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ template "base.name.release" . }}-rsyslog-config
  {{- include "mw.labels" . | indent 2}}
data:
  00-max-message-size.conf: |-
    $MaxMessageSize {{ .Values.mw.logging.rsyslog_max_message_size }}
  10-templates.conf: |-
{{ .Files.Get "rsyslog/templates.conf" | indent 4 }}
  20-mediawiki.conf: |-
{{ include "mw.rsyslog.application" . | indent 4 }}
  php-slowlog.rb: |-
{{ .Files.Get "rsyslog/slowlog.ruleset" | indent 4 }}
  php-errorlog.rb: |-
{{ .Files.Get "rsyslog/errorlog.ruleset" | indent 4 }}
{{- end -}}
