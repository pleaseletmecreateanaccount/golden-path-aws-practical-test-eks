{
  "widgets": [
    {
      "type": "text",
      "x": 0, "y": 0, "width": 24, "height": 1,
      "properties": {
        "markdown": "# 🚦 Golden Signals Dashboard — ${cluster_name} / ${namespace}\n**Latency · Traffic · Errors · Saturation**"
      }
    },

    {
      "type": "text",
      "x": 0, "y": 1, "width": 24, "height": 1,
      "properties": { "markdown": "## 1️⃣ Latency — How long requests take" }
    },
    {
      "type": "metric",
      "x": 0, "y": 2, "width": 12, "height": 6,
      "properties": {
        "title": "ALB Target Response Time (p50 / p95 / p99)",
        "view": "timeSeries",
        "stacked": false,
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "p50", "period": 60, "label": "p50 Latency" }],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "p95", "period": 60, "label": "p95 Latency" }],
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "p99", "period": 60, "label": "p99 Latency" }]
        ],
        "region": "${aws_region}",
        "yAxis": { "left": { "label": "Seconds", "min": 0 } }
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 2, "width": 12, "height": 6,
      "properties": {
        "title": "Pod Average Response Time (from Container Insights)",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "pod_network_rx_bytes", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Average", "period": 60, "label": "RX bytes/s" }],
          ["ContainerInsights", "pod_network_tx_bytes", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Average", "period": 60, "label": "TX bytes/s" }]
        ],
        "region": "${aws_region}"
      }
    },

    {
      "type": "text",
      "x": 0, "y": 8, "width": 24, "height": 1,
      "properties": { "markdown": "## 2️⃣ Traffic — How much demand is placed on the system" }
    },
    {
      "type": "metric",
      "x": 0, "y": 9, "width": 12, "height": 6,
      "properties": {
        "title": "ALB Request Count (RPS)",
        "view": "timeSeries",
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "Sum", "period": 60, "label": "Total Requests/min" }]
        ],
        "region": "${aws_region}",
        "yAxis": { "left": { "label": "Requests", "min": 0 } }
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 9, "width": 12, "height": 6,
      "properties": {
        "title": "Pod Count & HPA Replica Status",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "pod_number_of_running_containers", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Average", "period": 60, "label": "Running Pods" }]
        ],
        "region": "${aws_region}",
        "yAxis": { "left": { "label": "Pods", "min": 0 } }
      }
    },

    {
      "type": "text",
      "x": 0, "y": 15, "width": 24, "height": 1,
      "properties": { "markdown": "## 3️⃣ Errors — Rate of requests that fail" }
    },
    {
      "type": "metric",
      "x": 0, "y": 16, "width": 12, "height": 6,
      "properties": {
        "title": "ALB HTTP 4xx and 5xx Error Rates",
        "view": "timeSeries",
        "stacked": false,
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "Sum", "period": 60, "color": "#ff7f0e", "label": "4xx Errors" }],
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "app/${namespace}-alb/*",
            { "stat": "Sum", "period": 60, "color": "#d62728", "label": "5xx Errors" }]
        ],
        "region": "${aws_region}"
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 16, "width": 12, "height": 6,
      "properties": {
        "title": "Pod Restart Count (CrashLoopBackOff indicator)",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "pod_number_of_container_restarts", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Sum", "period": 60, "color": "#d62728", "label": "Container Restarts" }]
        ],
        "region": "${aws_region}"
      }
    },

    {
      "type": "text",
      "x": 0, "y": 22, "width": 24, "height": 1,
      "properties": { "markdown": "## 4️⃣ Saturation — How full the service is (CPU & Memory)" }
    },
    {
      "type": "metric",
      "x": 0, "y": 23, "width": 12, "height": 6,
      "properties": {
        "title": "Pod CPU Utilization % (triggers HPA)",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "pod_cpu_utilization", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Average", "period": 60, "label": "Avg CPU %" }],
          ["ContainerInsights", "pod_cpu_utilization", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "p95", "period": 60, "label": "p95 CPU %" }]
        ],
        "region": "${aws_region}",
        "annotations": {
          "horizontal": [{ "label": "HPA Scale-Out Threshold", "value": 70, "color": "#ff7f0e" }]
        }
      }
    },
    {
      "type": "metric",
      "x": 12, "y": 23, "width": 12, "height": 6,
      "properties": {
        "title": "Pod Memory Utilization %",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "pod_memory_utilization", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "Average", "period": 60, "label": "Avg Memory %" }],
          ["ContainerInsights", "pod_memory_utilization", "ClusterName", "${cluster_name}", "Namespace", "${namespace}",
            { "stat": "p95", "period": 60, "label": "p95 Memory %" }]
        ],
        "region": "${aws_region}",
        "annotations": {
          "horizontal": [{ "label": "Memory Warning", "value": 80, "color": "#ff7f0e" }]
        }
      }
    },
    {
      "type": "metric",
      "x": 0, "y": 29, "width": 24, "height": 6,
      "properties": {
        "title": "Node-Level: CPU & Memory Utilization",
        "view": "timeSeries",
        "metrics": [
          ["ContainerInsights", "node_cpu_utilization", "ClusterName", "${cluster_name}",
            { "stat": "Average", "period": 60, "label": "Node Avg CPU %" }],
          ["ContainerInsights", "node_memory_utilization", "ClusterName", "${cluster_name}",
            { "stat": "Average", "period": 60, "label": "Node Avg Memory %" }]
        ],
        "region": "${aws_region}"
      }
    }
  ]
}
