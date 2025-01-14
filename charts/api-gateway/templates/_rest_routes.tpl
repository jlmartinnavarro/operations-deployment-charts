{{- define "restgateway.routes" }}
            name: restgateway_route
            virtual_hosts:
            - name: restgateway_vhost
              domains:
{{- range $domain := .Values.main_app.domains }}
              - "{{ $domain }}"
{{- end }}

              response_headers_to_add:
                - header:
                    key: "access-control-allow-origin"
                    value: "*"
                  append: false
                - header:
                    key: "access-control-allow-methods"
                    value: "GET,HEAD"
                  append: false
                - header:
                    key: "access-control-allow-headers"
                    value: "accept, content-type, content-length, cache-control, accept-language, api-user-agent, if-match, if-modified-since, if-none-match, dnt, accept-encoding"
                  append: false
                - header:
                    key: "access-control-expose-headers"
                    value: "etag"
                  append: false
                - header:
                    key: "x-content-type-options"
                    value: "nosniff"
                  append: false
                - header:
                    key: "x-frame-options"
                    value: "SAMEORIGIN"
                  append: false
                - header:
                    key: "referrer-policy"
                    value: "origin-when-cross-origin"
                  append: false
                - header:
                    key: "x-xss-protection"
                    value: "1; mode=block"
                  append: false
              routes:
              - name: rest_gateway_root
                match:
                  path: "/"
                direct_response:
                  status: 200
                  body: {inline_string: "This is the REST Gateway."}
{{- /* BEGIN restbase_routes definition */}}
{{- range $endpoint, $endpoint_config := .Values.main_app.restbase_routes }}
{{- range $route_name, $route_paths := $endpoint_config.urls }}
              - name: {{ $endpoint }}_{{ $route_name }}
                match:
                  safe_regex:
                    google_re2: {}
                    regex: '^/{{ $route_paths.in }}$'
                route:
                  regex_rewrite:
                    pattern:
                      google_re2: {}
                      regex: '^{{ $route_paths.in }}$'
                    substitution: '{{ $route_paths.out }}'
                  timeout: {{ $endpoint_config.timeout | default "15s" }}
                  cluster: {{ $endpoint }}_cluster
                  {{- if $endpoint_config.ingress }}
                  auto_host_rewrite: true
                  {{- end }}
{{- end }}
{{- end }}
{{- /* END restbase_routes definition */}}


{{- end }}
