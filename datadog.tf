module "datadog" {
  source = "./datadog/"
  datadog-app-key = var.datadog_app_key
  datadog-api-key = var.datadog_api_key
  }


resource "datadog_api_key" "eks_cluster" {
  name = "${var.eks_cluster_name}-k8s-key"
}

resource "datadog_application_key" "eks_cluster" {
  name = "${var.eks_cluster_name}-k8s-key"
}

provider "datadog" {
   api_key = module.datadog.api-key
   app_key = module.datadog.app-key
 }

variable datadog_app_key {
  type = string
  }

variable datadog_api_key {
  type = string
  }

variable "kube-state-metrics_chart_version" {
  type = string
  default = "2.13.2"
  }

variable "datadog-agent_chart_version" {
  type = string
  default = "2.36.1"
  }

variable "datadog-crds_chart_version" {
  type = string
  default = "0.4.7"
  }

resource "helm_release" "datadog_crds" {
  name       = "datadog-crds"
  chart      = "datadog-crds"
  version    = var.datadog-crds_chart_version
  repository = "https://helm.datadoghq.com"
  depends_on = [ helm_release.kube-state-metrics ] 
 }

resource "helm_release" "datadog_agent" {
  name       = "datadog-agent"
  chart      = "datadog"
  version    = var.datadog-agent_chart_version
  repository = "https://helm.datadoghq.com"
  depends_on = [ helm_release.datadog_crds ] 


  set_sensitive {
    name  = "datadog.apiKey"
    value = datadog_api_key.eks_cluster.key
  }

  set_sensitive {
    name  = "datadog.appKey"
    value = datadog_application_key.eks_cluster.key
  }

  set {
    name  = "datadog.logs.enabled"
    value = true
  }

  set {
    name  = "datadog.logs.containerCollectAll"
    value = true
  }

  set {
    name  = "datadog.apm.enabled"
    value = true
  }

  set {
    name  = "datadog.kubeStateMetricsCore.enabled"
    value = true
  }

  set {
    name  = "datadog.leaderElection"
    value = true
  }

  set {
    name  = "datadog.collectEvents"
    value = true
  }

  set {
    name  = "clusterAgent.enabled"
    value = true
  }

  set {
    name  = "clusterAgent.metricsProvider.enabled"
    value = true
  }

  set {
    name  = "networkMonitoring.enabled"
    value = true
  }

  set {
    name  = "systemProbe.enableTCPQueueLength"
    value = true
  }

  set {
    name  = "systemProbe.enableOOMKill"
    value = true
  }

  set {
    name  = "securityAgent.runtime.enabled"
    value = true
  }

  set {
      name  = "datadog.hostVolumeMountPropagation"
      value = "HostToContainer"
  }
}

resource "helm_release" "kube-state-metrics" {
  name       = "kube-state-metrics"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-state-metrics"
  set {
        name = "rbac.create"
        value = true
    }
  set {
        name = "serviceAccount.create"
        value = true
    }
  set {
        name = "selfMonitor.enabled"
        value = true
      }

  version = var.kube-state-metrics_chart_version
  namespace  = "kube-system"
  depends_on = [ data.external.provision_crds ]
}
