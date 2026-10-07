class K8::Stateless::Deployment < K8::Base
  attr_accessor :service, :project, :environment_variables
  delegate :name, to: :service

  DEFAULT_PROBES = {
    "startupProbe" => { "periodSeconds" => 5, "failureThreshold" => 60 },
    "livenessProbe" => { "periodSeconds" => 20, "timeoutSeconds" => 10, "failureThreshold" => 3 },
    "readinessProbe" => { "periodSeconds" => 20, "timeoutSeconds" => 10, "failureThreshold" => 3 }
  }.freeze

  def initialize(service)
    @service = service
    @project = service.project
    @environment_variables = @project.environment_variables
  end

  # Default probes deep-merged with the service's override; null removes a probe,
  # a tcpSocket/exec/grpc handler replaces the default httpGet.
  def probes
    return {} unless service.web_service? && service.healthcheck_url.present?

    override = service.probes_yaml || {}
    Service::PROBE_NAMES.each_with_object({}) do |name, result|
      next if override.key?(name) && override[name].nil?

      # A fresh httpGet per probe: a shared Hash would be dumped as a YAML alias, which safe_load rejects
      base = DEFAULT_PROBES[name].merge("httpGet" => { "path" => service.healthcheck_url, "port" => service.container_port })
      base = base.except("httpGet") if (override[name] || {}).keys.intersect?(%w[tcpSocket exec grpc])
      result[name] = base.deep_merge(override[name] || {})
    end
  end

  def restart
    kubectl.call(%w[rollout restart] + [ "deployment/#{service.name}", "-n", project.namespace ])
  end
end
