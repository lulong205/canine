class ClusterPackage::Installer::VictoriaLogs < ClusterPackage::Installer::Base
  COLLECTOR = { release: "victoria-logs-collector", chart_url: "vm/victoria-logs-collector", version: "0.3.8" }.freeze
  SERVICE_NAME = "victoria-logs"
  DEFAULT_RETENTION_DAYS = 60
  DEFAULT_MAX_DISK_GIB = 20

  # Two charts: VictoriaLogs itself, then vlagent shipping every pod's logs to it.
  def install!(kubectl)
    helm = build_helm(kubectl)
    helm.add_repo(definition["repo_name"], definition["repo_url"])
    helm.repo_update(repo_name: definition["repo_name"])
    helm.install(definition["chart_name"], definition["chart_url"], definition["chart_version"],
      values: single_values, namespace: namespace, create_namespace: true)
    helm.install(COLLECTOR[:release], COLLECTOR[:chart_url], COLLECTOR[:version],
      values: collector_values, namespace: namespace, create_namespace: true)
  end

  def uninstall!(kubectl)
    helm = build_helm(kubectl)
    helm.uninstall(COLLECTOR[:release], namespace: namespace)
    helm.uninstall(definition["chart_name"], namespace: namespace)
  end

  private

  def namespace = Clusters::Install::DEFAULT_NAMESPACE

  def single_values
    days = config_int("retention_days", DEFAULT_RETENTION_DAYS)
    gib = config_int("max_disk_gib", DEFAULT_MAX_DISK_GIB)
    {
      "server" => {
        "fullnameOverride" => SERVICE_NAME,
        "retentionPeriod" => "#{days}d",
        "retentionDiskSpaceUsage" => "#{gib}GiB",
        "persistentVolume" => { "enabled" => true, "size" => "#{gib + 5}Gi" }
      }
    }
  end

  def collector_values
    { "remoteWrite" => [ { "url" => "http://#{SERVICE_NAME}.#{namespace}.svc:9428" } ] }
  end

  # Form fields arrive as strings; anything that isn't a positive integer falls back to the default.
  def config_int(key, default)
    value = Integer((package.config || {})[key], exception: false)
    value&.positive? ? value : default
  end
end
