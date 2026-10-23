"""
Triage keyword data and matching rules (pure Python, no third-party imports).

This module is deliberately standalone so the backend can vendor an identical
copy for its own fallback path. The backend sync test should assert
``keywords.KEYWORDS_VERSION`` is equal in both copies: it is a SHA-256 over
every data table below, so any drift in the lists changes it.

Severity (1-5, 5 = life threatening) is computed from clinical danger, never
from the order of the specialty list:

    5  life-threat phrase (LIFE_THREAT_*), or a compound rule such as
       "pregnant + bleeding"
    4  red-flag phrase (RED_FLAGS_4_*), a compound rule such as
       "child + fever", or a high-acuity specialty (cardiology, neurology,
       obstetrics)
    3  unrecognised text (cautious default) and most other specialties
    2  specialties recognised as usually low acuity (ent, eye, skin)

Roman Urdu and Urdu script lists are kept in their own tables
(``*_ROMAN_URDU`` / ``*_URDU``) and Roman Urdu spelling variants are folded
by ``ROMAN_URDU_SPELLINGS``. They were written without a native-speaker
review and MUST be reviewed and extended by one.

Known limit: negation ("no chest pain") is deliberately not handled. Over-
triaging a negated symptom costs a faster ambulance, missing a real one costs
a life, and Roman Urdu negation ("nahi") is part of the phrases themselves.
"""
from __future__ import annotations

import hashlib
import json
import re
import unicodedata

# ── ROMAN URDU SPELLING FOLDING (variant -> canonical token) ─────────────────
# Applied to every token of the input AND of every keyword phrase, so keyword
# phrases only need to be written once in any one spelling.

def _fold(canonical: str, *variants: str) -> dict[str, str]:
    return {variant: canonical for variant in variants}


ROMAN_URDU_SPELLINGS: dict[str, str] = {
    **_fold("nahi", "nahin", "nhi", "nai", "nahee", "nahe", "nahii", "nehi"),
    **_fold("saans", "sans", "saas", "saanss", "saanse", "sanse", "saaans"),
    **_fold("seena", "seene", "seenay", "seeney", "seenah", "sina", "sine", "sinay", "seeny"),
    **_fold("chaati", "chhati", "chati", "chhaati", "chaatee", "chhatti"),
    **_fold("me", "mein", "mai", "main", "men", "mey", "mei", "meen"),
    **_fold("ka", "ki", "ke"),
    **_fold("dard", "dardd", "durd"),
    **_fold("daura", "dora", "daora", "dawra", "daure", "daurey", "doray", "dauray"),
    **_fold("behosh", "bayhosh", "behush", "behoshi", "bhosh", "behoush", "baihosh", "behoosh"),
    **_fold("khoon", "khun", "khoom", "khon", "khoonn"),
    **_fold("beh", "bah", "bahe", "behna", "bahna", "behne", "bahne"),
    **_fold("raha", "rha", "rahi", "rhi", "rahe", "rhe", "rahay", "rahy", "rahee", "rahey"),
    **_fold("aa", "aati", "aata", "ati", "ata"),
    **_fold("bohat", "bahut", "boht", "bht", "buhat", "bohot", "buhut", "bohut", "bhot"),
    **_fold("ziada", "zyada", "zyadah", "ziyada", "zayada", "zaida", "zada"),
    **_fold("shadeed", "shadid"),
    **_fold("takleef", "taklif", "takleeef", "tkleef", "takkleef"),
    **_fold("dikkat", "dikat"),
    **_fold("lene", "lena", "lenay", "len", "lenee"),
    **_fold("phool", "phoolna", "phoolne", "phoola", "phoolti", "phulna", "phul"),
    **_fold("ruk", "ruka", "ruki", "rukna", "ruke", "rukk"),
    **_fold("toot", "toota", "tooti", "toote", "tuta"),
    **_fold("gaya", "gayi", "gaye", "gai", "gya", "gyi", "gye"),
    **_fold("gir", "gira", "giri", "gire", "girna", "girne"),
    **_fold("hil", "hila", "hili", "hile", "hilna", "hilne", "hilti", "hilta"),
    **_fold("sar", "sir", "sarr"),
    **_fold("kata", "kaata", "kat", "kati", "kate", "kaat", "kaatne", "katne"),
    **_fold("saanp", "saap", "sanp", "saanpp", "saamp"),
    **_fold("zehar", "zahar", "zehr", "zahr", "zeher", "zaher"),
    **_fold("mirgi", "mirgee", "mirgy", "mirghi"),
    **_fold("falij", "faalij", "falaj", "faalaj"),
    **_fold("lakwa", "lakva", "laqwa", "laqva"),
    **_fold("tedha", "terha", "teda", "tedhi", "terhi", "tedhay"),
    **_fold("neela", "neele", "neeli", "nila", "neelay", "nilay"),
    **_fold("hadsa", "hadisa", "hadsay", "hadsah", "haadsa"),
    **_fold("chaku", "chaaku", "chaqu", "chaaqu", "chakoo", "chaqoo"),
    **_fold("chot", "chott", "choat"),
    **_fold("goli", "goliyan", "goliya", "golian", "golia", "goliyaan", "golyan"),
    **_fold("doob", "dub", "dooba", "dooby", "doobna", "dubna", "doobne", "doobta"),
    **_fold("kuchal", "kuchla"),
    **_fold("karant", "karent", "karrant"),
    **_fold("jal", "jala", "jali", "jale", "jalna", "jalne", "jalta", "jalti"),
    **_fold("bacha", "bachay", "bachi", "bache", "bachcha", "bachchi", "bachche", "bachon",
            "bachchay", "bachha", "bacchon", "bacchay"),
    **_fold("bukhar", "bukhaar", "bukhr", "bukar", "bukharr"),
    **_fold("ulti", "ultiyan", "ultiyaan", "qay", "qai"),
    **_fold("dast", "dastt"),
    **_fold("pait", "pet"),
    **_fold("aankh", "ankh", "aankhen", "ankhen", "ankhein", "aankhein", "ankhain", "aankhon", "ankhon"),
    **_fold("gurda", "gurde", "gurdey", "gurday", "gurdah"),
    **_fold("peshab", "pishab", "peshaab", "pesab", "pishaab"),
    **_fold("khansi", "khaansi", "khansee", "khaasi", "khasi"),
    **_fold("dama", "damma"),
    **_fold("khudkushi", "khudkushee", "khudkashi", "khudkhushi", "khudkhashi", "khudkusi"),
    **_fold("ghabrahat", "ghabrat"),
    **_fold("dhadkan", "dharkan", "dhardkan", "dhadkn", "dharkn", "dhadakan"),
    **_fold("pani", "paani", "panee", "paanee"),
    **_fold("phat", "phata", "phati", "phate", "phatna", "phatne"),
    **_fold("nikal", "nikla", "nikli", "nikle", "nikalna", "nikalne", "nikalta", "nikalti"),
    **_fold("khol", "khola", "kholi", "khole", "kholna", "kholne"),
    **_fold("jawab", "jawaab", "jawb"),
    **_fold("uth", "utth", "uthna", "uthne", "utha", "uthi"),
    **_fold("jaag", "jag", "jaga", "jagna", "jagne", "jagti", "jagta"),
    **_fold("marna", "marnay", "marne"),
    **_fold("chahta", "chahti", "chahte", "chahtay"),
    **_fold("awaz", "awazen", "awaaz", "awaazen", "awazain"),
    **_fold("kha", "khaya", "khayi", "khai", "khaye", "khayin"),
    **_fold("lag", "lagi", "laga", "lage", "lagay", "lagna", "lagne", "lagta", "lagti"),
    **_fold("pad", "pada", "padi", "parh", "parha", "parhi", "padh", "para", "padha"),
    **_fold("bhari", "bhaari", "bhaaree", "bhaaree"),
}

# ── LIFE THREATS (severity 5) ────────────────────────────────────────────────

LIFE_THREAT_EN: tuple[str, ...] = (
    # breathing and airway
    "can't breathe", "cant breathe", "cannot breathe", "can not breathe", "can't breath",
    "cant breath", "cannot breath", "can not breath", "couldn't breathe", "could not breathe",
    "unable to breathe", "unable to breath", "not able to breathe", "not able to breath",
    "can't catch my breath", "cant catch my breath", "not breathing", "not breathe",
    "isn't breathing", "stopped breathing", "stops breathing", "no longer breathing",
    "barely breathing", "gasping", "struggling to breathe", "trouble breathing",
    "difficulty breathing", "difficult to breathe", "hard to breathe", "breathing difficulty",
    "shortness of breath", "short of breath", "breathless", "breathlessness", "choking",
    "choked", "chokes", "suffocating", "suffocation", "turning blue", "going blue", "gone blue",
    "blue lips", "lips are blue", "lips turning blue", "turned blue", "turns blue", "went blue",
    "cyanosis", "cyanotic", "chocking", "choaking",
    "anaphylaxis", "anaphylactic", "throat swelling", "throat is swelling", "swollen throat",
    "throat closing", "throat is closing", "tongue swelling", "swollen tongue",
    "severe allergic reaction", "allergic reaction severe", "serious allergic reaction",
    "severe allergy",
    # heart
    "chest pain", "chest pains", "pain in chest", "pain in the chest", "pain in my chest",
    "pain in his chest", "pain in her chest", "chest hurts", "chest is hurting",
    "chest tightness", "tight chest", "chest is tight", "tightness in chest",
    "tightness in the chest", "chest pressure", "pressure in chest", "pressure in the chest",
    "crushing pain", "heart attack", "cardiac arrest", "heart stopped", "heart stopping",
    "no pulse", "pulseless",
    # consciousness and neurology
    "unconscious", "unconsciousness", "unconcious", "not conscious", "lost consciousness",
    "loss of consciousness", "unresponsive", "non responsive", "nonresponsive",
    "not responding", "isn't responding", "collapsed", "collapse", "passed out", "pass out",
    "fainted", "fainting", "blacked out", "black out", "blackout", "not waking up",
    "won't wake up", "wont wake up", "can't wake", "cant wake", "cannot wake", "hard to wake",
    "unable to wake", "not able to wake", "can not wake",
    "gone limp", "went limp", "not moving", "isn't moving", "stopped moving", "motionless",
    "face drooping", "drooping face", "face droop", "facial droop", "face is drooping",
    "slurred speech", "speech is slurred", "slurred", "slurring", "can't speak", "cant speak",
    "cannot speak", "unable to speak", "trouble speaking", "difficulty speaking", "paralysed",
    "paralyzed", "paralysis", "one side weak", "weakness on one side", "one sided weakness",
    "numb on one side", "can't move one side", "cant move one side", "stroke", "brain stroke",
    "mini stroke", "sunstroke", "heatstroke", "brain bleed", "brain hemorrhage",
    "brain haemorrhage", "aneurysm", "worst headache", "sudden severe headache",
    "thunderclap headache", "seizure", "seizures", "seizing", "convulsion", "convulsions",
    "convulsing", "fits", "had a fit", "having a fit", "epileptic fit", "epileptic",
    "shaking uncontrollably", "foaming at the mouth", "foaming",
    # mental health, poisoning, overdose
    "suicidal", "suicide", "kill myself", "killing myself", "want to die", "wants to die",
    "wanna die", "kill himself", "kill herself", "kill themselves", "end my life", "ending my life", "end his life", "end her life",
    "take my own life", "take his own life", "take her own life", "self harm", "self-harm",
    "harming myself", "hurt myself", "hurting myself", "cutting myself", "slit wrist",
    "slit wrists", "cut my wrist", "cut his wrist", "cut her wrist", "hanging himself",
    "hanged himself", "hung himself", "tried to hang", "hanging", "overdose", "overdosed",
    "over dose", "took too many pills", "swallowed pills", "swallowed too many",
    "poison", "poisoned", "swallowed poison", "drank poison", "ate poison", "took poison",
    "rat poison", "pesticide", "pesticide poisoning", "gas poisoning", "chemical poisoning",
    "drug poisoning", "drank acid", "swallowed acid", "drank kerosene", "drank bleach",
    "swallowed bleach", "swallowed battery", "carbon monoxide", "smoke inhalation",
    # trauma
    "head injury", "head trauma", "head wound", "hit his head", "hit her head", "hit my head",
    "hit head", "hit the head", "banged his head", "banged her head", "blow to the head",
    "fell on head", "fell on his head", "fell on her head", "skull fracture",
    "bleeding from head", "bleeding from the head", "accident", "accidents", "car crash",
    "road crash", "bike crash", "motorcycle crash", "vehicle crash", "crashed into",
    "collision", "collided", "run over", "ran over", "hit by a car", "hit by car",
    "hit by a truck", "hit by a bus", "hit by a train", "hit and run", "gunshot",
    "gun shot", "gunshot wound", "been shot", "got shot", "shot in", "shot him", "shot her",
    "shot me", "bullet", "stabbed", "stab wound", "stabbing", "knife wound", "knifed",
    "fell from roof", "fell from the roof", "fell off roof", "fell off the roof",
    "fell from a height", "fell from height", "fell from building", "fell from the building",
    "fell from balcony", "fell from the balcony", "fell from tree", "fell from a tree",
    "fell from a ladder", "jumped from", "going to jump", "electrocuted", "electric shock",
    "electrocution", "drowning", "drowned", "nearly drowned", "snake bite", "snakebite",
    "bitten by a snake", "bitten by snake", "snake bit", "spinal injury", "spine injury",
    "broken neck", "broken back", "severe burn", "severe burns", "serious burn",
    "serious burns", "third degree", "burnt alive", "burned badly", "burnt badly",
    "burns all over", "acid attack", "acid thrown", "explosion", "cylinder blast", "blast",
    "trapped under",
    # bleeding
    "severe bleeding", "heavy bleeding", "bleeding heavily", "bleeds heavily", "bleed heavily",
    "bleeding profusely", "profuse bleeding", "bleeding badly", "bleeding severely",
    "severely bleeding", "bleeding a lot", "bleeds a lot", "lot of blood", "lots of blood",
    "losing blood", "lost a lot of blood", "blood loss", "severe blood loss", "internal bleeding",
    "bleeding won't stop", "bleeding wont stop", "bleeding will not stop",
    "bleeding does not stop", "bleeding not stopping", "bleeding doesn't stop",
    "bleeding doesnt stop", "can't stop the bleeding", "cant stop the bleeding",
    "cannot stop the bleeding", "uncontrolled bleeding", "uncontrollable bleeding",
    "hemorrhage", "haemorrhage", "hemorrhaging", "blood everywhere", "blood pouring",
    "gushing blood", "spurting blood", "vomiting blood", "vomited blood", "vomit blood",
    "vomiting up blood", "blood in vomit", "bloody vomit", "coughing blood", "coughing up blood",
    "cough blood", "coughed up blood", "coughing up red", "spitting blood",
    "heavy vaginal bleeding", "soaking pads", "soaked through pads",
    # pregnancy
    "water broke", "waters broke", "water has broken", "waters have broken", "my water broke",
    "membranes ruptured", "cord prolapse", "baby is coming", "baby coming", "baby is crowning",
    "crowning", "giving birth", "gave birth", "eclampsia", "preeclampsia", "baby not moving",
    "baby stopped moving", "no fetal movement", "not crying", "born at home",
    # death
    "dying", "is dead", "looks dead", "died", "not alive", "going to die", "about to die",
)

LIFE_THREAT_ROMAN_URDU: tuple[str, ...] = (
    # breathing
    "saans nahi", "saans lene", "saans me takleef", "saans me mushkil", "saans me dikkat",
    "saans phool", "saans ruk", "saans band", "saans ukhad", "dam ghut", "dam ghutna",
    "dam nikal", "dam phool", "dam tod",
    # chest and heart
    "seena me dard", "seena dard", "dard seena me", "seena bhari", "seena me bhari", "seena jakar",
    "seena jakran", "seena me jakran", "seena me takleef", "seena band", "seene par dabao",
    "seena dabao", "chaati me dard", "chaati me jakran", "chaati bhari", "dil me dard",
    "dil dard", "dil ka daura", "dil band", "dil ruk", "dil ki dhadkan band", "dhadkan band",
    "dhadkan ruk", "heart attack",
    # consciousness
    "behosh", "be hosh", "bay hosh", "hosh nahi", "hosh me nahi", "hosh khoo", "hosh gum",
    "hosh kho", "ghash", "chakkar kha ke gir", "chakkar kha kar gir", "chakkar aa ke gir",
    "jawab nahi de", "reply nahi", "aankh nahi khol", "jaag nahi", "mar gaya", "mar gayi",
    "marne wala", "marne wali", "marne ke qareeb", "mar jaye ga", "dam toot",
    # bleeding
    "khoon beh", "khoon bahut", "bohat khoon", "ziada khoon", "khoon nahi ruk", "khoon ruk nahi",
    "khoon band nahi", "khoon nikal", "khoon ki ulti", "khoon wali ulti", "ulti me khoon",
    "khoon thook", "khoon thookna", "khansi me khoon", "khoon ki qay",
    # mental health and poisoning
    "khudkushi", "khud kushi", "khud kashi", "jaan dene", "jaan de dun", "jaan de doon",
    "apni jaan", "jaan lena", "marna chahta", "mar jana chahta", "zindagi khatam",
    "zindagi khatm", "khud ko khatam", "khud ko nuqsan", "khud ko maar", "nas kata", "phansi",
    "zehar", "zehreela", "zehar khurani", "chuha maar", "chuhay maar", "goli kha",
    "bohat si goli", "bohat saari goli", "overdose", "tezab pi", "phenyl pi", "phenyl",
    "mitti ka tel pi", "kerosene", "celphos", "sulphas", "sulfas", "gehoon ki goli",
    "gandum ki goli",
    # seizure and stroke
    "mirgi", "mirgi ka daura", "daura pad", "daura par", "jhatke", "jhatkay", "jhatkon",
    "akad gaya", "akar gaya", "munh se jhag", "munh se jhaag", "jhag nikal", "jhaag nikal",
    "ainthan", "aithan", "enthan", "aynthan", "falij", "lakwa", "munh tedha", "chehra tedha",
    "munh ek taraf", "chehra ek taraf", "zuban larkhara", "zuban nahi chal", "zuban band",
    "bol nahi", "bolne me mushkil", "bolne me takleef", "bolne me dushwari",
    "ek taraf se kamzor", "ek taraf kamzori", "nahi hil", "nas phat", "rag phat",
    # trauma
    "accident", "hadsa", "takkar", "gari ne takkar", "gari ne kuchal", "kuchal", "sar par chot",
    "sar me chot", "sar pe chot", "sar ki chot", "sar phat", "sar se khoon", "sar ke bal",
    "goli lag", "goli maar", "goli chal", "chaku lag", "chaku maar", "chaku se", "chhuri lag",
    "chhuri maar", "karant lag", "current lag", "bijli ka jhatka", "bijli ka karant", "doob",
    "saanp ne kata", "saanp kata", "saanp ka kata", "chaat se gir", "chat se gir", "chhat se gir",
    "darakht se gir", "balcony se gir", "imarat se gir", "bohat jal", "buri tarah jal",
    "aag lag", "aag me jal", "neela par", "neela ho", "hont neela", "jism neela", "chehra neela",
    # pregnancy
    "pani toot", "pani phat", "pani nikal", "bacha hone wala", "bacha hone wali",
    "paidaish ka dard", "delivery ka dard", "delivery pain", "dard zeh", "dard e zeh",
    "bacha bahar aa", "bacha nikal",
)

LIFE_THREAT_URDU: tuple[str, ...] = (
    # breathing
    "سانس نہیں", "سانس لینے", "سانس میں تکلیف", "سانس میں دشواری", "سانس پھول", "سانس رک",
    "سانس بند", "سانس اکھڑ", "دم گھٹ", "دم نکل",
    # chest and heart
    "سینے میں درد", "سینے میں جکڑن", "سینے میں تکلیف", "سینے میں بھاری", "سینے پر دباؤ",
    "سینے میں دباؤ", "چھاتی میں درد", "سینہ درد", "دل کا دورہ", "دل بند", "دل رک",
    "دل میں درد", "ہارٹ اٹیک", "دل کی دھڑکن بند",
    # consciousness
    "بے ہوش", "بیہوش", "بےہوش", "بیہوشی", "ہوش نہیں", "ہوش میں نہیں", "ہوش کھو",
    "جواب نہیں دے", "جواب نہیں دیتا", "جواب نہیں دیتی", "آنکھیں نہیں کھول", "جاگ نہیں", "چکر کھا کر گر", "چکر کھا کے گر", "غش",
    "مر گیا", "مر گئی", "مرنے والا", "مرنے کے قریب",
    # bleeding
    "خون بہہ", "خون بہ رہا", "خون بہت", "بہت خون", "زیادہ خون", "خون نہیں رک", "خون رک نہیں",
    "خون نکل", "خون کی الٹی", "الٹی میں خون", "خون والی الٹی", "خون تھوک", "کھانسی میں خون",
    # mental health and poisoning
    "خودکشی", "خود کشی", "جان دینا", "جان دے", "اپنی جان", "مرنا چاہتا", "مرنا چاہتی", "مر جانا چاہتا", "مر جانا چاہتی",
    "زندگی ختم", "خود کو ختم", "خود کو نقصان", "نس کاٹ", "پھانسی", "زہر", "زہریلی",
    "زہریلا", "گولیاں کھا", "بہت سی گولیاں", "اوور ڈوز", "اوورڈوز", "تیزاب پی", "فینائل",
    "سلفاس", "سیلفاس", "گندم کی گولی", "گندم کی گولیاں", "مٹی کا تیل پی", "چوہے مار",
    # seizure and stroke
    "مرگی", "دورہ پڑ", "دورہ پڑا", "دورہ پڑی", "دورے پڑ", "دورے پڑے", "دورے پڑتے", "جھٹکے", "اکڑ گیا", "اکڑ گئی", "منہ سے جھاگ", "جھاگ",
    "اینٹھن", "تشنج", "فالج", "لقوہ", "منہ ٹیڑھا", "چہرہ ٹیڑھا", "زبان لڑکھڑا", "بول نہیں",
    "بولنے میں", "ایک طرف سے کمزور", "ایک طرف کمزور", "ہل نہیں", "اسٹروک", "برین ہیمریج",
    # trauma
    "حادثہ", "حادثے", "ایکسیڈنٹ", "ٹکر", "ٹکرا", "سر پر چوٹ", "سر میں چوٹ", "سر پھٹ", "سر پھٹا",
    "سر سے خون", "گولی لگ", "گولی لگی", "گولی لگا", "چاقو", "چھری", "کرنٹ لگ", "کرنٹ لگا", "کرنٹ لگی", "بجلی کا جھٹکا", "ڈوب",
    "ڈوبا", "ڈوبنے", "ڈوبتا", "ڈوبتی", "سانپ نے کاٹ", "سانپ کاٹ", "سانپ کے کاٹ",
    "چھت سے گر", "چھت سے گرا", "چھت سے گری", "درخت سے گر", "درخت سے گرا", "آگ لگ", "آگ لگی", "بری طرح جل", "نیلا پڑ", "ہونٹ نیلے", "نیلا ہو",
    "جسم نیلا",
    # pregnancy
    "پانی ٹوٹ", "بچہ ہونے والا", "زچگی کا درد", "ڈیلیوری کا درد", "درد زہ",
)

# ── RED FLAGS (severity 4) ───────────────────────────────────────────────────

RED_FLAGS_4_EN: tuple[str, ...] = (
    # breathing (pulmonology red flags)
    "breathing", "breathe", "wheezing", "wheeze", "asthma", "asthma attack", "fast breathing",
    "rapid breathing", "breathing fast", "breathing problem", "breathing problems",
    "chest infection", "chest congestion", "noisy breathing", "labored breathing",
    "laboured breathing",
    # general acuity
    "confused", "confusion", "disoriented", "not making sense", "severe headache",
    "terrible headache", "high fever", "very high fever", "fever and rash", "fever with rash",
    "stiff neck", "neck stiffness", "cold sweat", "cold sweats", "sweating a lot",
    "profuse sweating", "high blood pressure", "bp high", "bp is high", "blood pressure high",
    "hypertension", "low blood pressure", "bp low", "bp is low", "low bp", "low blood sugar",
    "high blood sugar", "sugar very high", "sugar very low", "sugar is low", "sugar is high",
    "hypoglycemia", "hyperglycemia", "jaundice", "yellow eyes", "yellow skin",
    "sudden numbness", "sudden vision loss", "loss of vision", "lost vision", "can't see",
    "cant see", "blurred vision", "double vision", "eye injury", "chemical in eye",
    # bleeding and gut
    "bleeding", "bleed", "bleeds", "blood in urine", "blood in stool", "bloody stool",
    "bloody diarrhea", "black stool", "black stools", "tarry stool", "rectal bleeding",
    "vaginal bleeding", "persistent vomiting", "continuous vomiting", "vomiting continuously",
    "non stop vomiting", "nonstop vomiting", "severe vomiting", "dehydrated", "dehydration",
    "severe diarrhea", "severe diarrhoea", "food poisoning", "appendicitis", "kidney stone",
    # injuries
    "burn", "burns", "burnt", "burned", "scald", "scalded", "burn injury", "open fracture",
    "compound fracture", "bone sticking out", "bone is sticking out", "bone exposed",
    "deformed", "dislocated", "dislocation", "fell down", "fell off", "fell from", "had a fall",
    "took a fall", "slipped and fell", "fell over", "neck injury", "back injury", "unable to walk",
    "can't walk", "cant walk", "cannot walk", "can't stand", "cant stand", "unable to stand",
    "dog bite", "dog bit", "bitten by a dog", "bitten by dog", "animal bite", "monkey bite",
    "scorpion", "swallowed", "ingested",
    # allergy
    "allergic reaction", "swollen face", "face swelling", "swelling of face", "swollen lips",
    "lip swelling", "swelling of lips",
    # mental health
    "mental breakdown", "nervous breakdown", "hallucination", "hallucinations", "hallucinating",
    "hearing voices", "seeing things", "delusions", "psychosis", "psychotic", "violent",
    "aggressive", "agitated", "out of control", "panic attack", "severe anxiety",
    # obstetric
    "miscarriage",
)

RED_FLAGS_4_ROMAN_URDU: tuple[str, ...] = (
    "saans", "dama", "seena", "chaati", "dil ghabra", "dhadkan", "chakkar", "khoon",
    "tez bukhar", "bukhar tez", "bohat bukhar", "ziada bukhar", "shadeed bukhar",
    "bukhar ziada", "ulti nahi ruk", "ulti band nahi", "lagatar ulti", "musalsal ulti",
    "bohat ulti", "ziada ulti", "dast aur ulti", "ulti aur dast", "gir gaya", "jal gaya", "pagalpan",
    "awaz sunai", "uth nahi", "kutte ne kata", "kutta kata", "bichu",
)

RED_FLAGS_4_URDU: tuple[str, ...] = (
    "سانس", "دمہ", "سینہ", "سینے", "چھاتی", "دل گھبرا", "دھڑکن", "چکر", "خون", "تیز بخار",
    "بہت بخار", "شدید بخار", "گر گیا", "گر گئی", "جل گیا", "جل گئی", "پاگل پن", "آواز سنائی",
    "کتے نے کاٹ", "بچھو",
)

# ── COMPOUND RULES: a context word AND a flag word anywhere in the text ──────

PREGNANCY_ESCALATORS: tuple[str, ...] = (
    "bleeding", "bleed", "blood", "spotting", "leaking fluid", "fluid leaking", "water leaking",
    "severe headache", "blurred vision", "reduced movement", "less movement", "khoon", "خون",
)

PEDIATRIC_ESCALATORS: tuple[str, ...] = (
    "fever", "high fever", "temperature", "vomiting", "vomit", "diarrhea", "diarrhoea",
    "loose motions", "not feeding", "not eating", "refusing feed", "refusing to eat",
    "not drinking", "lethargic", "sleepy", "drowsy", "floppy", "weak", "pale", "dehydrated",
    "dehydration", "rash", "swallowed", "ingested", "cough", "crying non stop",
    "inconsolable", "pain", "bukhar", "ulti", "dast", "doodh nahi", "khana nahi", "sust",
    "kamzor", "بخار", "الٹی", "دست", "کمزور", "سست",
)

INTENSITY_WORDS: tuple[str, ...] = (
    "severe", "severely", "unbearable", "excruciating", "terrible", "intense", "extreme",
    "agonizing", "agony", "shadeed", "bohat", "ziada", "bardasht", "شدید", "بہت", "زیادہ",
    "برداشت",
)

PAIN_WORDS: tuple[str, ...] = (
    "pain", "pains", "painful", "ache", "headache", "hurts", "hurting", "dard", "درد", "تکلیف",
)

# ── SPECIALTIES ──────────────────────────────────────────────────────────────

_PEDIATRIC_AGE_PHRASES: tuple[str, ...] = tuple(
    f"{n} {unit} old" for n in range(1, 13) for unit in ("year", "years", "yr", "yrs")
) + ("month old", "months old", "week old", "weeks old", "day old", "days old")

SPECIALTY_KEYWORDS_EN: dict[str, tuple[str, ...]] = {
    "obstetrics": (
        "pregnant", "pregnancy", "labour", "labor", "delivery", "contractions", "water broke",
        "waters broke", "miscarriage", "antenatal", "c section", "cesarean", "caesarean",
        "baby is coming", "giving birth", "expecting", "trimester", "eclampsia", "preeclampsia",
    ),
    "pediatrics": (
        "child", "children", "kid", "kids", "infant", "baby", "babies", "toddler", "newborn",
        "pediatric", "paediatric",
    ) + _PEDIATRIC_AGE_PHRASES,
    "cardiology": (
        "chest", "chest pain", "heart", "heart attack", "palpitation", "palpitations", "cardiac",
        "angina", "blood pressure", "hypertension", "irregular heartbeat", "racing heart",
    ),
    "neurology": (
        "stroke", "brain", "unconscious", "unconsciousness", "numbness", "numb", "can't talk",
        "cant talk", "slurred", "slurring", "seizure", "seizures", "convulsion", "convulsions",
        "fits", "epilepsy", "epileptic", "headache", "migraine", "paralysis", "paralyzed",
        "paralysed", "face drooping", "head injury", "hit his head", "hit her head",
        "hit my head", "hit head", "head wound", "skull fracture", "fainted", "passed out", "dizziness",
        "faint", "fainting", "fitting", "unconcious",
    ),
    "pulmonology": (
        "breathing", "breathe", "breath", "breathless", "lungs", "lung", "asthma", "copd",
        "respiratory", "cough", "coughing", "wheezing", "wheeze", "pneumonia", "choking",
        "choked", "suffocating",
    ),
    "orthopedics": (
        "broken", "fracture", "fractured", "joint", "joints", "bone", "bones", "sprain",
        "dislocated", "dislocation", "back pain",
    ),
    "psychiatry": (
        "mental", "anxiety", "depression", "hallucination", "hallucinations", "suicidal",
        "suicide", "self harm", "self-harm", "panic", "psychosis", "bipolar", "schizophrenia",
        "hearing voices", "depressed", "kill myself", "kill himself", "kill herself", "want to die",
        "wants to die", "end my life", "end his life", "end her life",
    ),
    "nephrology": ("kidney", "kidneys", "dialysis", "renal", "urine"),
    "gastroenterology": (
        "stomach", "abdomen", "abdominal", "vomit", "vomiting", "diarrhea", "diarrhoea",
        "bowel", "belly", "gastric", "stool",
    ),
    "oncology": ("cancer", "tumor", "tumour", "chemotherapy", "chemo", "radiation therapy"),
    "ent": ("ear", "ears", "nose", "throat", "hearing", "tonsil", "tonsils", "sinus"),
    "ophthalmology": ("eye", "eyes", "vision", "blind"),
    "dermatology": (
        "skin", "rash", "burn", "burns", "allergy", "allergic", "itching", "hives",
    ),
}

SPECIALTY_KEYWORDS_ROMAN_URDU: dict[str, tuple[str, ...]] = {
    "obstetrics": ("hamila", "zachgi", "pani toot", "dard e zeh", "dard zeh", "delivery"),
    "pediatrics": ("bacha", "nawzaeeda", "nanha", "shir khwar"),
    "cardiology": ("dil", "seena", "dhadkan", "chaati", "dil ka daura", "dil me dard"),
    "neurology": (
        "dimagh", "mirgi", "falij", "lakwa", "behosh", "sar dard", "sar me dard", "daura pad",
        "chakkar", "munh tedha", "chehra tedha", "zuban larkhara", "larkhara", "sar par chot", "sar me chot", "sar pe chot", "sar ki chot",
    ),
    "pulmonology": ("saans", "khansi", "dama"),
    "orthopedics": (
        "haddi", "haddi toot", "haath toot", "taang toot", "bazu toot", "pair toot", "moch",
    ),
    "psychiatry": ("zehni", "ghabrahat", "khudkushi", "khud kushi", "pagalpan"),
    "nephrology": ("gurda", "peshab"),
    "gastroenterology": ("pait", "pait dard", "ulti", "dast", "qabz"),
    "oncology": ("kainsar", "rasoli"),
    "ent": ("kaan", "naak", "gala"),
    "ophthalmology": ("aankh", "nazar"),
    "dermatology": ("jild", "khujli", "daane"),
}

SPECIALTY_KEYWORDS_URDU: dict[str, tuple[str, ...]] = {
    "obstetrics": ("حاملہ", "زچگی", "ڈیلیوری", "درد زہ", "پانی ٹوٹ"),
    "pediatrics": ("بچہ", "بچی", "بچے", "بچوں", "نومولود", "شیر خوار"),
    "cardiology": ("دل", "سینے", "سینہ", "دھڑکن", "چھاتی", "ہارٹ اٹیک", "دل کا دورہ"),
    "neurology": ("دماغ", "مرگی", "فالج", "لقوہ", "بے ہوش", "بیہوش", "سر درد", "دورہ پڑ", "تشنج"),
    "pulmonology": ("سانس", "کھانسی", "دمہ"),
    "orthopedics": ("ہڈی", "جوڑ", "فریکچر", "موچ"),
    "psychiatry": ("ڈپریشن", "خودکشی", "ذہنی", "گھبراہٹ"),
    "nephrology": ("گردے", "گردہ", "پیشاب", "ڈائلیسس"),
    "gastroenterology": ("پیٹ", "الٹی", "دست", "اسہال", "معدہ"),
    "oncology": ("کینسر", "رسولی"),
    "ent": ("کان", "ناک", "گلا"),
    "ophthalmology": ("آنکھ", "نظر", "آنکھیں"),
    "dermatology": ("جلد", "کھجلی", "الرجی"),
}

# Tie-break order when several specialties score equally (most dangerous first).
SPECIALTY_PRIORITY: tuple[str, ...] = (
    "cardiology", "neurology", "pulmonology", "orthopedics", "psychiatry", "nephrology",
    "gastroenterology", "oncology", "ent", "ophthalmology", "dermatology",
)

# These two decide the specialty whenever they match at all.
CONTEXT_FIRST_SPECIALTIES: tuple[str, ...] = ("obstetrics", "pediatrics")

FALLBACK_SPECIALTY = "general_emergency"

# Floor severity of each recognised specialty. The text is scored against ALL
# matched specialties and the highest floor wins, so a child with a racing
# heart is not rated by "pediatrics" alone.
SPECIALTY_BASE_SEVERITY: dict[str, int] = {
    "cardiology": 4, "neurology": 4, "obstetrics": 4, "pulmonology": 3, "psychiatry": 3,
    "pediatrics": 3, "orthopedics": 3, "gastroenterology": 3, "nephrology": 3, "oncology": 3,
    "ophthalmology": 2, "ent": 2, "dermatology": 2,
}

# Unrecognised text is NOT low acuity. It gets this cautious default.
UNKNOWN_SEVERITY = 3

NO_MATCH_CONFIDENCE = 0.30


def _specialty_phrases(name: str) -> tuple[str, ...]:
    return (
        SPECIALTY_KEYWORDS_EN.get(name, ())
        + SPECIALTY_KEYWORDS_ROMAN_URDU.get(name, ())
        + SPECIALTY_KEYWORDS_URDU.get(name, ())
    )


# (severity, context phrases, flag phrases): fires when both groups match.
COMPOUND_RULES: tuple[tuple[int, tuple[str, ...], tuple[str, ...]], ...] = (
    (5, _specialty_phrases("obstetrics"), PREGNANCY_ESCALATORS),
    (4, _specialty_phrases("pediatrics"), PEDIATRIC_ESCALATORS),
    (4, INTENSITY_WORDS, PAIN_WORDS),
)


def _compute_version() -> str:
    data = {
        "spellings": ROMAN_URDU_SPELLINGS,
        "life_threat": [LIFE_THREAT_EN, LIFE_THREAT_ROMAN_URDU, LIFE_THREAT_URDU],
        "red_flags": [RED_FLAGS_4_EN, RED_FLAGS_4_ROMAN_URDU, RED_FLAGS_4_URDU],
        "compound": COMPOUND_RULES,
        "specialties": [
            SPECIALTY_KEYWORDS_EN, SPECIALTY_KEYWORDS_ROMAN_URDU, SPECIALTY_KEYWORDS_URDU,
        ],
        "rules": [
            SPECIALTY_PRIORITY, CONTEXT_FIRST_SPECIALTIES, FALLBACK_SPECIALTY,
            SPECIALTY_BASE_SEVERITY, UNKNOWN_SEVERITY, NO_MATCH_CONFIDENCE,
        ],
    }
    blob = json.dumps(data, sort_keys=True, ensure_ascii=True, separators=(",", ":"))
    return hashlib.sha256(blob.encode("ascii")).hexdigest()


# SHA-256 over every data table above. The backend sync test compares this.
KEYWORDS_VERSION: str = _compute_version()

# ── NORMALISATION ────────────────────────────────────────────────────────────

_DROPPED_CHARS = {ord(c): None for c in "'’‘ʼʻ′`´"}
_ARABIC_TO_URDU = {
    0x064A: "ی", 0x0649: "ی",  # yeh variants -> Farsi yeh
    0x0643: "ک",                    # Arabic kaf -> Urdu kaf
    0x0647: "ہ", 0x0629: "ہ",  # heh, teh marbuta -> heh goal
    0x06c3: "ہ", 0x06be: "ہ",  # teh marbuta goal, do-chashmi heh -> heh goal
    0x06ba: "ن",                    # noon ghunna -> noon
}
_NON_WORD = re.compile(r"[\W_]+")
_URDU_SCRIPT = re.compile(r"[؀-ۿ]")


def normalise(text: str) -> str:
    """Fold case, accents, apostrophes, punctuation, Urdu letter variants and
    Roman Urdu spellings so ``Can’t``, ``cant`` and ``CAN'T`` compare equal.

    Raises TypeError for non-strings (callers must not pass bytes or None).
    """
    if not isinstance(text, str):
        raise TypeError(f"text must be str, got {type(text).__name__}")
    # Apostrophes go first: NFKD would turn U+00B4 into a space.
    folded = unicodedata.normalize("NFKD", text.translate(_DROPPED_CHARS)).casefold()
    folded = "".join(c for c in folded if unicodedata.category(c) not in ("Mn", "Cf"))
    folded = folded.translate(_ARABIC_TO_URDU)
    tokens = _NON_WORD.sub(" ", folded).split()
    return " ".join(ROMAN_URDU_SPELLINGS.get(token, token) for token in tokens)


# ── MATCHING ─────────────────────────────────────────────────────────────────

def _phrase_regex(phrase: str) -> str:
    normalised = normalise(phrase)
    # Urdu script is spaced inconsistently (آ رہی / آرہی), so spaces are optional.
    separator = r"\s*" if _URDU_SCRIPT.search(normalised) else r"\s+"
    body = separator.join(re.escape(word) for word in normalised.split())
    return rf"(?<!\w){body}(?!\w)"


def _compile_any(phrases: tuple[str, ...]) -> re.Pattern[str]:
    regexes = sorted({_phrase_regex(p) for p in phrases}, key=len, reverse=True)
    return re.compile("|".join(regexes))


_LIFE_THREAT = _compile_any(LIFE_THREAT_EN + LIFE_THREAT_ROMAN_URDU + LIFE_THREAT_URDU)
_RED_FLAG = _compile_any(RED_FLAGS_4_EN + RED_FLAGS_4_ROMAN_URDU + RED_FLAGS_4_URDU)
_COMPOUND = tuple(
    (severity, _compile_any(context), _compile_any(flags))
    for severity, context, flags in COMPOUND_RULES
)
_SPECIALTY_PATTERNS: dict[str, tuple[re.Pattern[str], ...]] = {
    name: tuple(
        re.compile(rx) for rx in sorted({_phrase_regex(p) for p in _specialty_phrases(name)})
    )
    for name in (*CONTEXT_FIRST_SPECIALTIES, *SPECIALTY_PRIORITY)
}


def _score_specialties(norm: str) -> dict[str, int]:
    """Count the distinct keywords of each specialty found in the text."""
    return {
        name: sum(1 for pattern in patterns if pattern.search(norm))
        for name, patterns in _SPECIALTY_PATTERNS.items()
    }


def _pick_specialty(scores: dict[str, int]) -> tuple[str, int, int]:
    """Return (specialty, its score, best other score)."""
    chosen = next((s for s in CONTEXT_FIRST_SPECIALTIES if scores[s] > 0), None)
    if chosen is None:
        ranked = sorted(SPECIALTY_PRIORITY, key=lambda s: (-scores[s], SPECIALTY_PRIORITY.index(s)))
        chosen = ranked[0]
        if scores[chosen] == 0:
            return FALLBACK_SPECIALTY, 0, 0
    runner_up = max((v for k, v in scores.items() if k != chosen), default=0)
    return chosen, scores[chosen], runner_up


def _confidence(score: int, runner_up: int) -> float:
    """Heuristic match strength in [0.30, 0.90]. NOT a calibrated probability.

    More distinct keyword hits raise it, a competing specialty lowers it, and
    no hit at all gives NO_MATCH_CONFIDENCE. It has never been validated
    against labelled outcomes.
    """
    if score == 0:
        return NO_MATCH_CONFIDENCE
    raw = 0.35 + 0.15 * min(score, 3) - 0.10 * min(runner_up / score, 1.0)
    return round(max(0.30, min(0.90, raw)), 2)


def _severity(norm: str, scores: dict[str, int]) -> tuple[int, bool]:
    if _LIFE_THREAT.search(norm):
        return 5, True
    compound = [s for s, context, flags in _COMPOUND if context.search(norm) and flags.search(norm)]
    if compound and max(compound) == 5:
        return 5, True
    if _RED_FLAG.search(norm) or compound:
        return 4, False
    floors = [SPECIALTY_BASE_SEVERITY[s] for s, n in scores.items() if n > 0]
    return max(floors, default=UNKNOWN_SEVERITY), False


# ── PUBLIC API ───────────────────────────────────────────────────────────────

def detect_severity_override(text: str) -> bool:
    """True when the text contains a life-threat phrase (or compound rule)."""
    norm = normalise(text)
    return _severity(norm, _score_specialties(norm))[1]


def infer_specialty(text: str) -> tuple[str, float]:
    """Return (specialty, heuristic confidence). See ``_confidence``."""
    specialty, score, runner_up = _pick_specialty(_score_specialties(normalise(text)))
    return specialty, _confidence(score, runner_up)


def compute_severity(text: str) -> tuple[str, bool]:
    """Return (severity "1".."5", rule_override). rule_override is True only
    when the 5 was forced by a life-threat rule."""
    norm = normalise(text)
    level, forced = _severity(norm, _score_specialties(norm))
    return str(level), forced
