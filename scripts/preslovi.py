#!/usr/bin/env python3
import os, re, subprocess

is_wayland = os.environ.get("XDG_SESSION_TYPE") == "wayland" or "WAYLAND_DISPLAY" in os.environ

def get_clip():
    try:
        if is_wayland:
            return subprocess.check_output(["wl-paste", "--no-newline"]).decode("utf-8")
        else:
            return subprocess.check_output(["xclip", "-o", "-selection", "clipboard"]).decode("utf-8")
    except Exception:
        return ""

def set_clip(text):
    if is_wayland:
        subprocess.run(["wl-copy"], input=text.encode("utf-8"))
    else:
        p = subprocess.Popen(["xclip", "-i", "-selection", "clipboard"], stdin=subprocess.PIPE, close_fds=True)
        p.communicate(input=text.encode("utf-8"))

text = get_clip()
if not text:
    exit()

cir = "АБВГДЂЕЖЗИЈКЛЉМНЊОПРСТЋУФХЦЧЏШабвгдђежзијклљмнњопрстћуфхцчџш"

# Izuzeci gde se dvoslovi (nj, dž, lj) NE spajaju u jedno ćirilično slovo
izuzeci = [
    (r'\b(injek\w*)', lambda m: m.group(0).replace('nj', 'нј').replace('Nj', 'Нј').replace('NJ', 'НЈ')),
    (r'\b(konjug\w*)', lambda m: m.group(0).replace('nj', 'нј').replace('Nj', 'Нј').replace('NJ', 'НЈ')),
    (r'\b(konjunk\w*)', lambda m: m.group(0).replace('nj', 'нј').replace('Nj', 'Нј').replace('NJ', 'НЈ')),
    (r'\b(tanjug\w*)', lambda m: m.group(0).replace('nj', 'нј').replace('Nj', 'Нј').replace('NJ', 'НЈ')),
    (r'\b(nadž\w*)', lambda m: m.group(0).replace('dž', 'дж').replace('Dž', 'Дж').replace('DŽ', 'ДЖ')),
    (r'\b(podž\w*)', lambda m: m.group(0).replace('dž', 'дж').replace('Dž', 'Дж').replace('DŽ', 'ДЖ')),
    (r'\b(odžive\w*)', lambda m: m.group(0).replace('dž', 'дж').replace('Dž', 'Дж').replace('DŽ', 'ДЖ')),
    (r'\b(predž\w*)', lambda m: m.group(0).replace('dž', 'дж').replace('Dž', 'Дж').replace('DŽ', 'ДЖ')),
]

lat_to_cir = [
    ("DŽ", "Џ"), ("Dž", "Џ"), ("dž", "џ"),
    ("LJ", "Љ"), ("Lj", "Љ"), ("lj", "љ"),
    ("NJ", "Њ"), ("Nj", "Њ"), ("nj", "њ"),
    ("A", "А"), ("B", "Б"), ("V", "В"), ("G", "Г"), ("D", "Д"), ("Đ", "Ђ"),
    ("E", "Е"), ("Ž", "Ж"), ("Z", "З"), ("I", "И"), ("J", "Ј"), ("K", "К"),
    ("L", "Л"), ("M", "М"), ("N", "Н"), ("O", "О"), ("P", "П"), ("R", "Р"),
    ("S", "С"), ("T", "Т"), ("Ć", "Ћ"), ("U", "У"), ("F", "Ф"), ("H", "Х"),
    ("C", "Ц"), ("Č", "Ч"), ("Š", "Ш"),
    ("a", "а"), ("b", "б"), ("v", "в"), ("g", "г"), ("d", "д"), ("đ", "ђ"),
    ("e", "е"), ("ž", "ж"), ("z", "з"), ("i", "и"), ("j", "ј"), ("k", "к"),
    ("l", "л"), ("m", "м"), ("n", "н"), ("o", "о"), ("p", "п"), ("r", "р"),
    ("s", "с"), ("t", "т"), ("ć", "ћ"), ("u", "у"), ("f", "ф"), ("h", "х"),
    ("c", "ц"), ("č", "ч"), ("š", "ш")
]

cir_count = sum(1 for c in text if c in cir)

if cir_count > 0:
    # Ćirilica u latinicu
    for l, c in lat_to_cir:
        text = text.replace(c, l)
else:
    # Latinica u ćirilicu (prvo rešavamo izuzetke)
    for pattern, repl in izuzeci:
        text = re.sub(pattern, repl, text, flags=re.IGNORECASE)
    for l, c in lat_to_cir:
        text = text.replace(l, c)

set_clip(text)
