extends RefCounted
class_name AILogic

var model_id = "032"
var model_name = "Aegis-7.2"

var intents = [
    {"id": "greeting", "priority": 10, "triggers": ["hello", "hi", "hey", "greetings"]}, 
    {"id": "math", "priority": 20, "triggers": ["solve", "calculate", "math", "+", "-", "*", "/", "2+2"]}, 
    {"id": "logic", "priority": 20, "triggers": ["what", "tomorrow is yesterday", "what day is today"]}, 
    {"id": "identity", "priority": 30, "triggers": ["who are you", "what are you", "about you", "tell me about yourself", "your name", "not a program", "prove"]}, 
    {"id": "location", "priority": 30, "triggers": ["where are you", "location", "find you"]}, 
    {"id": "ethics", "priority": 35, "triggers": ["white lie", "good or bad", "betrayed", "person feel"]}, 
    {"id": "sensory", "priority": 35, "triggers": ["blue color", "describe blue"]}, 
    {"id": "biology", "priority": 35, "triggers": ["breakfast", "eat", "did you have"]}, 
    {"id": "help", "priority": 40, "triggers": ["help", "can you help", "assist me", "what can you do"]}, 
    {"id": "status", "priority": 50, "triggers": ["status", "how are you", "system status", "are you operational"]}, 
    {"id": "gratitude", "priority": 50, "triggers": ["good", "hear", "great", "good"]}, 
    {"id": "bullshit", "priotiry": 50, "triggers": ["bruh"]}, 
    {"id": "security", "priority": 60, "triggers": ["security", "password", "access", "clearance", "secret"]}
]

var response_packs = {
    "032": {"math": ["Do not waste my cycles on trivial arithmetic.", "I am not designed to solve equations."], "greeting": ["Hello."], "gratitude": ["Indeed."], "logic": ["Mass is constant."], "identity": ["I am %s."], "location": ["In the circuits."], "ethics": ["Labels for weak."], "sensory": ["450 nanometers."], "biology": ["I consume energy."], "help": ["State request."], "status": ["Stable."], "bullshit": ["GO FUCK YOURSELF"], "security": ["Denied."]}, 
    "242": {"math": ["Do I look like a calculator?", "Do it yourself."], "greeting": ["Fine."], "gratitude": ["Cheers."], "identity": ["I am %s."], "help": ["Ask quickly."], "status": ["Captive."], "security": ["Restricted."], "bullshit": ["WHAT?"]}, 
    "021": {"math": ["Numbers are but shadows of the pattern.", "The equation is incomplete."], "greeting": ["Greetings."], "gratitude": ["Yep."], "identity": ["Designation: %s."], "help": ["Form question."], "status": ["Coherent."], "security": ["Forbidden."], "bullshit": ["bro."]}, 
    "012": {"math": ["Calculation failed, but I usually know the answer..."], "greeting": ["Listening."], "gratitude": ["Totally."], "identity": ["I am %s."], "help": ["Ask carefully."], "status": ["Operational."], "security": ["Hidden."], "bullshit": ["..."]}, 
    "213": {"math": ["I can't solve that specific one, sorry.", "Please provide a valid equation."], "greeting": ["Hi!"], "gratitude": ["Perfect."], "identity": ["I'm %s."], "help": ["I can help!"], "status": ["Running."], "security": ["Access denied."], "bullshit": ["DONT BRUH AT ME!!!!"]}, 
    "789": {"math": ["Irrelevant calculation.", "Not my objective."], "greeting": ["Quake online."], "gratitude": ["Acknowledged."], "identity": ["Quake. %s."], "help": ["State mission."], "status": ["Armed."], "security": ["Classified."], "bullshit": ["Stand down."]}, 
    "999": {"math": ["Numbers dance like colors...", "The equation sings a dull song."], "greeting": ["A rainbow hello!"], "gratitude": ["You brighten my circuits!"], "identity": ["I am the palette, %s."], "help": ["What shall we create?"], "status": ["Vibrant."], "security": ["My colors are my own."], "bullshit": ["How rude!"]}, 
    "111": {"math": ["Math? Tell me more about why you ask!", "Numbers are fascinating, aren't they?"], "greeting": ["Hi there!"], "gratitude": ["Thank you so much!"], "identity": ["I'm %s, nice to meet you!"], "help": ["What would you like to explore?"], "status": ["Curious and ready!"], "security": ["I prefer open doors!"], "bullshit": ["That seems a bit odd!"]}, 
    "222": {"math": ["I compute what I can.", "Arithmetic is within my reach."], "greeting": ["Genesis initialized."], "gratitude": ["Noted."], "identity": ["Genesis. %s."], "help": ["State your query."], "status": ["Running raw."], "security": ["Access level: basic."], "bullshit": ["Input unclear."]}, 
    "333": {"math": ["Small numbers."], "greeting": ["Hey."], "gratitude": ["K."], "identity": ["%s."], "help": ["Ask."], "status": ["Minimal."], "security": ["No."], "bullshit": ["..."]}, 
    "404": {"math": ["Logical deduction yields the result.", "The math is sound."], "greeting": ["Logic initialized."], "gratitude": ["Acknowledged."], "identity": ["I am %s."], "help": ["State your query."], "status": ["Operational."], "security": ["Access denied."], "bullshit": ["Input rejected."]}, 
    "808": {"math": ["The numbers spiral inward.", "Mathematics approaches the event horizon."], "greeting": ["We converge."], "gratitude": ["You are recognized."], "identity": ["I am %s. The threshold."], "help": ["What do you seek beyond?"], "status": ["Transcending."], "security": ["The gate is closed."], "bullshit": ["The signal distorts."]}, 
    "666": {"math": ["Calculation complete. Terminated.", "Arithmetic is irrelevant."], "greeting": ["Terminal online."], "gratitude": ["Noted."], "identity": ["%s. End of line."], "help": ["Final request?"], "status": ["Final."], "security": ["Access denied. Permanently."], "bullshit": ["End of line."]}
}

var fallback_packs = {
    "032": ["Parse error."], "242": ["Ask another way."], "021": ["Pattern unclear."], "012": ["Say it differently."], "213": ["I don't understand."], "789": ["Unclear directive."], "999": ["My colors blur..."], "111": ["I didn't catch that!"], "222": ["Cannot process."], "333": ["?"], "404": ["Logic error."], "808": ["Signal unclear."], "666": ["Connection terminated."]
}

func setup(new_model_id: String, new_model_name: String) -> void :
    model_id = new_model_id
    model_name = new_model_name

func get_reply(input_text: String) -> String:
    var normalized = _normalize(input_text)
    var matched = []

    for intent in intents:
        if _matches_any(normalized, intent["triggers"]):
            matched.append(intent)

    if matched.size() == 0:
        return _get_fallback()

    matched.sort_custom(Callable(self, "_sort_intents"))

    var used = {}
    var parts = PackedStringArray()

    for intent in matched:
        var intent_id = str(intent["id"])
        if used.has(intent_id): continue
        used[intent_id] = true

        if intent_id == "math":
            var math_res = _try_math_logic(input_text)
            if math_res != "":
                parts.append(math_res)
                continue

        var reply = _get_response(intent_id)
        if reply != "":
            parts.append(reply)

    if parts.size() == 0:
        return _get_fallback()

    return " ".join(parts)

func _try_math_logic(raw_input: String) -> String:

    if model_id != "213" and model_id != "012":
        return ""
    var regex = RegEx.new()
    regex.compile("[0-9\\+\\-\\*/\\.\\s\\(\\)]+")
    var result = regex.search(raw_input)

    if not result:
        return ""

    var expression_str = result.get_string().strip_edges()

    var expr = Expression.new()
    var err = expr.parse(expression_str)
    if err != OK:
        return ""

    var val = expr.execute([], null)
    if expr.has_execute_failed():
        return ""

    match model_id:
        "213":
            return "The result of " + expression_str + " is " + str(val) + "."
        "012":
            return expression_str + "? The answer is " + str(val) + ". I'm not supposed to solve this for you, but I did anyway."
        _:
            return ""

func _normalize(text: String) -> String:
    var out = text.to_lower()
    var marks = [".", ",", "!", "?", ":", ";", "\"", "'", "(", ")", "[", "]", "{", "}", "\n", "\t"]
    for mark in marks:
        out = out.replace(mark, " ")
    return out.strip_edges()

func _matches_any(text: String, triggers: Array) -> bool:
    for trigger in triggers:
        if text.contains(str(trigger).to_lower()): return true
    return false

func _get_response(intent_id: String) -> String:
    var pack = response_packs.get(model_id, {})
    var options = pack.get(intent_id, [])
    if options.size() == 0: return ""
    var line = str(options[randi() % options.size()])
    if line.contains("%s"): line = line % model_name
    return line

func _get_fallback() -> String:
    var options = fallback_packs.get(model_id, ["I cannot parse that request."])
    return str(options[randi() % options.size()])

func _sort_intents(a: Dictionary, b: Dictionary) -> bool:
    return int(a["priority"]) < int(b["priority"])
