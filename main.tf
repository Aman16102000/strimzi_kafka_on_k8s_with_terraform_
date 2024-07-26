resource "kubernetes_namespace" "strimzi_ns" {
  metadata {
    name = "strimzi-ns"
  }
}

resource "helm_release" "strimzi_operator" {
  name       = "strimzi-operator"
  repository = "https://strimzi.io/charts/"
  chart      = "strimzi-kafka-operator"
  version    = "0.39.0"

  namespace = kubernetes_namespace.strimzi_ns.metadata[0].name
  values = [
    <<EOF
    resources:
      limits:
        memory: 1Gi
      requests:
        memory: 512Mi

    topicOperator:
      enabled: true
    EOF
  ]
}

resource "kubernetes_manifest" "kafka_cluster" {
  depends_on = [ helm_release.strimzi_operator ]
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "Kafka"
    metadata = {
      name      = "kafka-cluster"
      namespace = kubernetes_namespace.strimzi_ns.metadata[0].name
    }
    spec = {
      kafka = {
        version = "3.5.0"
        replicas = 3
        listeners = [
          {
            name = "plain"
            port = 9092
            type = "internal"
            tls  = false
          }
          ,
          {
            name = "tls"
            port = 9093
            type = "internal"
            tls  = true
          }
        ]
        config = {
          "offsets.topic.replication.factor" = 3
          "transaction.state.log.replication.factor" = 3
          "transaction.state.log.min.isr" = 2
          "log.message.format.version" = "2.8"
        }
        storage = {
          type = "jbod"
          volumes = [
            {
              id = 0
              type = "persistent-claim"
              size = "10Gi"
              deleteClaim = false
            }
          ]
        }
      }
      zookeeper = {
        replicas = 3
        storage = {
          type = "persistent-claim"
          size = "10Gi"
          deleteClaim = false
        }

      }
      entityOperator = {
        topicOperator = {}
        userOperator = {}
      }
    }
  }
}

# kafka topic with partitions

resource "kubernetes_manifest" "kafka_topic" {
  depends_on = [ kubernetes_manifest.kafka_cluster ]
  manifest = {
    apiVersion = "kafka.strimzi.io/v1beta2"
    kind       = "KafkaTopic"
    metadata = {
      name      = "sample-topic"
      namespace = kubernetes_namespace.strimzi_ns.metadata[0].name
      labels = {
        "strimzi.io/cluster" = "kafka-cluster"
      }
    }
    spec = {
      partitions = 10
      replicas   = 3
      topicName  = "sample-topic"
    }
  }
}
