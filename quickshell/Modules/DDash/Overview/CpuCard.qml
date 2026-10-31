import QtQuick
import qs.Common
import qs.Services
import qs.Modules.DDash

MetricCard {
    entryId: "cpu"
    dgopModules: ["cpu"]
    label: I18n.tr("CPU")
    iconName: "memory"
    usage: options.visualStyle === "clavis" && DgopService.cpuHistory.length === 0 ? -1 : (DgopService.cpuUsage || 0) / 100
    valueText: options.visualStyle === "clavis" && DgopService.cpuHistory.length === 0 ? "--" : Math.round(DgopService.cpuUsage || 0) + "%"
    supportingText: DgopService.cpuModel
    badgeText: (options.visualStyle === "clavis" || options.temperature === true) && DgopService.cpuTemperature > 0 ? Math.round(DgopService.cpuTemperature) + "°" : ""
    showTrend: options.trend === true
    trend: DgopService.cpuHistory
}
