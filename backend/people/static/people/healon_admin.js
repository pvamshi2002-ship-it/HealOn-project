(function () {
  function getChartData() {
    var node = document.getElementById("healon-chart-data");
    if (!node) {
      return null;
    }
    try {
      return JSON.parse(node.textContent);
    } catch (error) {
      return null;
    }
  }

  function buildCharts() {
    var data = getChartData();
    if (!data || !window.Chart) {
      return;
    }

    var textColor = "#334155";
    var gridColor = "#e2e8f0";
    var baseOptions = {
      responsive: true,
      maintainAspectRatio: true,
      plugins: {
        legend: {
          labels: {
            color: textColor,
            boxWidth: 12,
            font: { weight: "700" }
          }
        }
      },
      scales: {
        x: {
          ticks: { color: textColor },
          grid: { display: false }
        },
        y: {
          beginAtZero: true,
          ticks: { color: textColor, precision: 0 },
          grid: { color: gridColor }
        }
      }
    };

    function chart(id, config) {
      var canvas = document.getElementById(id);
      if (canvas) {
        new Chart(canvas, config);
      }
    }

    chart("attendanceTrendChart", {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [{
          label: "Attendance",
          data: data.attendance,
          backgroundColor: "#10b981",
          borderRadius: 8
        }]
      },
      options: baseOptions
    });

    chart("leaveAnalyticsChart", {
      type: "pie",
      data: {
        labels: data.leave_labels,
        datasets: [{
          data: data.leave_values,
          backgroundColor: ["#10b981", "#f59e0b", "#ef4444"],
          borderColor: "#ffffff",
          borderWidth: 3
        }]
      },
      options: {
        responsive: true,
        plugins: {
          legend: {
            position: "bottom",
            labels: { color: textColor, font: { weight: "700" } }
          }
        }
      }
    });

    chart("employeeGrowthChart", {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [{
          label: "New Employees",
          data: data.employee_growth,
          backgroundColor: "#0f172a",
          borderRadius: 8
        }]
      },
      options: baseOptions
    });

    chart("payrollSummaryChart", {
      type: "bar",
      data: {
        labels: data.labels,
        datasets: [{
          label: "Payroll",
          data: data.payroll,
          backgroundColor: "#2563eb",
          borderRadius: 8
        }]
      },
      options: baseOptions
    });
  }

  function waitForCharts(attemptsLeft) {
    if (window.Chart) {
      buildCharts();
      return;
    }
    if (attemptsLeft > 0) {
      window.setTimeout(function () {
        waitForCharts(attemptsLeft - 1);
      }, 120);
    }
  }

  document.addEventListener("DOMContentLoaded", function () {
    waitForCharts(30);
  });
})();
