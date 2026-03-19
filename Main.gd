extends Control

onready var status_label = $Panel/StatusLabel
onready var start_button = $Panel/StartButton
onready var stop_button = $Panel/StopButton
onready var mode_select = $Panel/ModeSelect
onready var strategy_select = $Panel/StrategySelect
onready var log_text = $Panel/LogText
onready var test_button = $Panel/TestButton

var is_running = false
var is_testing = false
var bypass_thread = null
var current_strategy = {}

# База стратегий
var strategies = {
    "auto": {"name": "🤖 АВТО", "params": null},
    "strategy1": {"name": "📦 Фрагментация", "params": {"fragment": true, "ttl": 65, "delay": 0}},
    "strategy2": {"name": "🔄 TTL 63", "params": {"fragment": false, "ttl": 63, "delay": 5}},
    "strategy3": {"name": "🔀 Фрагм+TTL", "params": {"fragment": true, "ttl": 128, "delay": 10}},
    "strategy4": {"name": "⚡ Анти-DPI", "params": {"fragment": true, "ttl": 1, "delay": 15}},
}

var test_targets = [
    {"name": "Telegram", "host": "149.154.167.50"},
    {"name": "YouTube", "host": "216.58.192.0"},
    {"name": "Google", "host": "8.8.8.8"},
]

var working_strategies = []

func _ready():
    start_button.connect("pressed", self, "_on_start")
    stop_button.connect("pressed", self, "_on_stop")
    test_button.connect("pressed", self, "_on_test")
    
    for s in strategies:
        strategy_select.add_item(strategies[s].name)
    strategy_select.select(0)
    
    status_label.text = "⚡ ОСТАНОВЛЕН"
    log("🔧 Система готова")

func _on_test():
    if is_testing: return
    is_testing = true
    log("🧪 ТЕСТ СТРАТЕГИЙ...")
    var test_thread = Thread.new()
    test_thread.start(self, "_test_strategies")

func _test_strategies():
    working_strategies.clear()
    for s in strategies:
        if s == "auto": continue
        var strategy_name = strategies[s].name
        var params = strategies[s].params
        log("🔄 " + strategy_name)
        
        var success_count = 0
        for target in test_targets:
            var result = _test_strategy(params, target)
            if result:
                success_count += 1
                log("  ✅ " + target.name)
            else:
                log("  ❌ " + target.name)
            OS.delay_msec(500)
        
        var success_rate = (float(success_count) / test_targets.size()) * 100
        if success_rate >= 66:
            working_strategies.append({"name": strategy_name, "params": params, "rate": success_rate})
            log("✅ РАБОЧАЯ: " + strategy_name)
        else:
            log("❌ НЕ РАБОЧАЯ: " + strategy_name)
    
    is_testing = false
    log("🏁 ТЕСТ ЗАВЕРШЁН")

func _test_strategy(params, target):
    var cmd = "ping"
    var args = ["-c", "1", "-W", "2"]
    if params.ttl != 64:
        args += ["-t", str(params.ttl)]
    args += [target.host]
    var exit_code = OS.execute(cmd, args, true, [])
    if params.fragment and exit_code != 0:
        var frag_args = ["-c", "1", "-s", "100", target.host]
        exit_code = OS.execute(cmd, frag_args, true, [])
    return exit_code == 0

func _on_start():
    if is_running: return
    var selected_idx = strategy_select.selected
    var keys = strategies.keys()
    var selected_key = keys[selected_idx] if selected_idx < keys.size() else "auto"
    
    if selected_key == "auto" and working_strategies.size() > 0:
        current_strategy = working_strategies[0].params
        log("🤖 АВТО: " + working_strategies[0].name)
    else:
        current_strategy = strategies[selected_key].params if strategies[selected_key].has("params") else {"fragment": true, "ttl": 64, "delay": 0}
    
    is_running = true
    status_label.text = "🔥 АКТИВЕН"
    log("🚀 ЗАПУСК")
    bypass_thread = Thread.new()
    bypass_thread.start(self, "_bypass_worker", current_strategy)

func _on_stop():
    if not is_running: return
    is_running = false
    status_label.text = "⚡ ОСТАНОВЛЕН"
    if bypass_thread:
        bypass_thread.wait_to_finish()
    log("⛔ ОСТАНОВЛЕНО")

func _bypass_worker(params):
    var all_ips = ["149.154.167.50", "216.58.192.0", "8.8.8.8"]
    var ping_count = 0
    while is_running:
        for ip in all_ips:
            if not is_running: break
            var args = ["-c", "1", "-W", "1"]
            if params.ttl != 64: args += ["-t", str(params.ttl)]
            args += [ip]
            OS.execute("ping", args, true, [])
            if params.fragment:
                OS.execute("ping", ["-c", "1", "-s", "500", ip], true, [])
            ping_count += 1
            if ping_count % 30 == 0:
                log("📊 Пингов: " + str(ping_count))
            if params.delay > 0:
                OS.delay_msec(params.delay)

func log(message):
    call_deferred("_add_log", message)

func _add_log(message):
    var time = OS.get_time()
    var time_str = "%02d:%02d:%02d" % [time.hour, time.minute, time.second]
    log_text.text = "[" + time_str + "] " + message + "\n" + log_text.text
    if log_text.text.length() > 5000:
        log_text.text = log_text.text.substr(0, 5000)
