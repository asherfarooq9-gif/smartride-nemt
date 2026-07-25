"""
A small, HAND-WRITTEN evaluation set -- deliberately NOT produced by
generate_dataset.py's templates. Messier, terser, more varied phrasing,
closer to how someone actually types while panicked or distracted.

Why this file exists: hospital_routing_test.csv is drawn from the same
closed template vocabulary as hospital_routing_train.csv (same symptom
phrases, same subject list, same duration/closing phrases -- just different
combinations). A model can score very well on that test set purely by
recognizing template patterns, without proving it can handle real,
unstructured patient/family messages. This file is a second, independent
check that isn't subject to that inflation. Treat accuracy on THIS file,
not on hospital_routing_test.csv, as your honest estimate of where you
stand against the >92% target -- and expect it to be noticeably lower
than the template-test-set number.
"""

import csv

HOLDOUT = [
    ("Sir please help, my brother met an accident on the motorway and there's a lot of blood, we need help right now!!", "Emergency_Trauma"),
    ("Fell down the stairs at home, can't move his leg, need pickup fast", "Emergency_Trauma"),
    ("kitchen fire, my mother's hand and arm got burned badly, please send someone immediately", "Emergency_Trauma"),
    ("car hit my father on the road just now he's not talking properly", "Emergency_Trauma"),

    ("My uncle keeps clutching his chest and sweating a lot, we're really scared, please hurry", "Cardiology"),
    ("chest pain again for abbu, same as last time before his bypass, need to reach hospital", "Cardiology"),
    ("Grandpa's heart rate feels all over the place and he says he's dizzy", "Cardiology"),
    ("need transport tomorrow for angiography, can you confirm pickup time", "Cardiology"),

    ("one side of my mother's face suddenly dropped and her speech is slurred, is this a stroke??", "Neurology"),
    ("brother just had a seizure, shaking all over, please come quick", "Neurology"),
    ("grandmother can't move her right arm since this morning and seems very confused", "Neurology"),
    ("need a ride for dad's MRI follow up next week for his headaches", "Neurology"),

    ("twisted my ankle badly playing cricket, it's huge and swollen, cant walk", "Orthopedics"),
    ("mom fell in the bathroom, leg looks bent wrong, please send help", "Orthopedics"),
    ("physio session booked for uncle at 4pm, need the wheelchair van", "Orthopedics"),
    ("dad's knee surgery follow up is tomorrow morning, can u arrange pickup", "Orthopedics"),

    ("3 dialysis sessions a week for my father, need reliable pickup every time, is that possible", "Nephrology_Dialysis"),
    ("missed dialysis yesterday bc no ride, doctor said come in today no matter what", "Nephrology_Dialysis"),
    ("grandmother's legs are super swollen and she's not peeing much, dr said bring her in", "Nephrology_Dialysis"),
    ("fistula check before dialysis this thursday for uncle", "Nephrology_Dialysis"),

    ("chemo session for my wife today at 11, need wheelchair accessible car", "Oncology"),
    ("after last chemo my mother can barely walk, please send someone to help her to the car", "Oncology"),
    ("scan follow up booked for next tuesday, cancer patient, need transport", "Oncology"),
    ("biopsy appointment tomorrow for my father please confirm pickup", "Oncology"),

    ("wife's water broke!! we need to go now please hurry", "Obstetrics_Gynecology"),
    ("sister having really bad cramps and bleeding, she's pregnant, please send car fast", "Obstetrics_Gynecology"),
    ("routine checkup for my daughter in law tomorrow morning, she's pregnant", "Obstetrics_Gynecology"),
    ("ultrasound appointment booked for thursday, need pickup for my wife", "Obstetrics_Gynecology"),

    ("baby has high fever since last night wont stop crying, so worried", "Pediatrics"),
    ("my son swallowed a coin!! need to get to hospital now", "Pediatrics"),
    ("daughter fell off her bike, arm looks weird, crying a lot", "Pediatrics"),
    ("vaccination appointment for my newborn next week tuesday", "Pediatrics"),

    ("grandfather can't breathe properly, his oxygen machine reading is dropping fast", "Pulmonology"),
    ("asthma attack, my brother's inhaler isn't working, please hurry", "Pulmonology"),
    ("coughing up blood since yesterday, really scared, need to see a doctor", "Pulmonology"),
    ("follow up for lung infection next week, need transport", "Pulmonology"),

    ("my son is acting really strange, not making sense, we don't know what to do", "Psychiatry_MentalHealth"),
    ("sister having a panic attack, can't breathe properly, shaking a lot", "Psychiatry_MentalHealth"),
    ("dad hasn't recognized any of us for two days now, please help", "Psychiatry_MentalHealth"),
    ("regular psychiatric appointment for my brother this friday", "Psychiatry_MentalHealth"),

    ("mom's had fever and body pain for 3 days, meds not working", "General_Medicine"),
    ("dad's sugar levels are all over the place, needs a checkup", "General_Medicine"),
    ("just feeling really weak and dizzy today, want to see a doctor", "General_Medicine"),
    ("routine blood test booked for next monday", "General_Medicine"),

    ("throwing up blood, very weak, please send help now", "Gastroenterology"),
    ("dad's eyes have gone yellow, we're worried it's his liver", "Gastroenterology"),
    ("chronic acid reflux, need gastro consultation booked for wednesday", "Gastroenterology"),
    ("severe stomach pain since morning, can't stand straight", "Gastroenterology"),

    ("grandma's nose won't stop bleeding, it's been 20 mins", "ENT"),
    ("ear infection, my son is in a lot of pain and has fever", "ENT"),
    ("throat so swollen he can barely swallow, please hurry", "ENT"),
    ("hearing test appointment booked for next week for dad", "ENT"),

    ("can't pass urine at all, in a lot of pain, please help fast", "Urology"),
    ("blood in urine this morning, very worried, need to see a doctor", "Urology"),
    ("recurring UTI, needs a urology checkup, can book for anytime this week", "Urology"),
    ("catheter change appointment tomorrow for my grandfather", "Urology"),
]

if __name__ == "__main__":
    path = "dataset_out/hospital_routing_true_holdout.csv"
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(["text", "label"])
        writer.writerows(HOLDOUT)
    print(f"Wrote {len(HOLDOUT)} hand-written examples to {path}")
    from collections import Counter
    print(Counter(label for _, label in HOLDOUT))
