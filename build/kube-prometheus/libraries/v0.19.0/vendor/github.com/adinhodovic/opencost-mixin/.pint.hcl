rule {
  match {
    name = "OpenCostAnomalyDetected"
  }
  disable = ["promql/impossible"]
}

rule {
  match {
    name = "OpenCostMonthlyBudgetExceeded"
  }
  disable = ["promql/impossible"]
}
