class Projects::LogsController < Projects::BaseController
  def index
    @services = @project.services.order(:name).pluck(:name)
    @service = params[:service].presence_in(@services)
    @q = params[:q].to_s.strip.first(200).presence
    @range = params[:range].presence_in(K8::VictoriaLogs::RANGES) || "1h"
    @live = params[:live] != "0"

    kubectl = K8::Kubectl.new(active_connection)
    @endpoint = K8::VictoriaLogs.locate(kubectl, @project.cluster)
    return unless @endpoint

    @rows = K8::VictoriaLogs.new(kubectl, @endpoint)
      .search(namespace: @project.namespace, service: @service, text: @q, range: @range)
  rescue Cli::CommandFailedError, JSON::ParserError => e
    @error = e.message
  end
end
