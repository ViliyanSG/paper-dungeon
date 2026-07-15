extends Node2D
## Paper Dungeon — core loop (Godot 4)
## Roll a die: odd = diagonal move, even = orthogonal move; number = steps
## (stops at wall). After rolling, up to 4 destination options appear;
## click one to slide there in a straight line. The travelled path is kept
## as a continuous pencil line. Touch + mouse supported.

const GAME_VERSION := "dev"   # stamped with the CI build number on release
const TILE := 36
const COLS := 20
const ROWS := 20
const GRID_TOP := 100   # px from top where the play field starts

const ORTHO_DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
const DIAG_DIRS := [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]

# ---- Paper theme colors ----
const C_PAPER := Color(0.957, 0.937, 0.882)
const C_LINE := Color(0.85, 0.81, 0.70)
const C_INK := Color(0.17, 0.17, 0.17)
const C_RED := Color(0.70, 0.23, 0.28)
const C_GREEN := Color(0.29, 0.49, 0.35)
const C_GOLD := Color(0.79, 0.64, 0.15)
const C_BROWN := Color(0.54, 0.43, 0.23)
const C_BLUE := Color(0.11, 0.23, 0.36)
const C_GRAY := Color(0.6, 0.6, 0.6)
const C_TEXT := Color(0.90, 0.86, 0.76)
const C_WALL := Color(0.361, 0.322, 0.275)
const C_WALL_HI := Color(0.471, 0.424, 0.361)
const C_WALL_LO := Color(0.227, 0.196, 0.165)
const C_PANEL := Color(0.172, 0.149, 0.125)
const C_BG := Color(0.13, 0.12, 0.11)      # dark stone backdrop
const C_BG_LO := Color(0.09, 0.08, 0.075)  # mortar
const C_BG_HI := Color(0.18, 0.165, 0.15)  # brick top edge
# design-system roles
const C_ACCENT := Color(0.910, 0.765, 0.290) # gold accent text
const C_CREAM := Color(0.910, 0.874, 0.784)  # primary text
const C_MUTED := Color(0.604, 0.561, 0.478)  # muted text

# ---- Pixel sprites (8x8 maps + palette) ----
const SPRITES := {
	"enemy": ["........", "..GGGG..", ".GGGGGG.", "GGGGGGGG", "GWBGGWBG", "GGGGGGGG", "EGGGGGGE", ".EEEEEE."],
	"skull": ["..nnnn..", ".nnnnnn.", "nnnnnnnn", "nKKnnKKn", "nnnKKnnn", "nnnnnnnn", ".nKnKn..", "..nnnn.."],
	"trap": ["........", "m.m.m.m.", "mmmmmmmm", "MmMmMmMm", "MMMMMMMM", "oooooooo", "OoOoOoOo", "OOOOOOOO"],
	"beartrap": ["..MMMM..", ".MmmmmM.", "MmKKKKmM", "MmKKKKmM", "MmmmmmmM", ".MmmmmM.", "..MMMM..", "........"],
	"coin": ["..KKKK..", ".KgyygK.", "KgyyggsK", "KgygggsK", "KgygggsK", "KgggggsK", ".KgsssK.", "..KKKK.."],
	"heart": [".rr..rr.", "rprrrrrr", "rrrrrrrr", "rrrrrrrr", ".rrrrrr.", "..rrrr..", "...rr...", "........"],
	"chest": ["........", ".KKKKKK.", ".KwwwwK.", ".gggggg.", ".KwllwK.", ".KwllwK.", ".KKKKKK.", "........"],
	"player": ["...dd...", "..dddd..", "..ffff..", "..fKfK..", ".buuuub.", ".uUUUUu.", "..u..u..", "..b..b.."],
	"knight": ["....KKKK....", "...KaaaaK...", "..KaaaaaaK..", "..KaKKKKaK..", "..KaaaaaaK..", "...KAAAAK...", ".KAAggAAK...", ".KAaggaAK...", ".KAaaaaAK...", "..AAaaAA....", "..AA..AA....", ".KKK..KKK..."],
	"mage": [".....K......", "....KvK.....", "...KvvvK....", "..KvvvvvK...", ".KvvvvvvvK..", "...KffffK...", "...KfKKfK...", "..KVVVVVVK..", ".KVvvvvvVK..", ".KVvvyvvVK..", ".KVvvvvvVK..", "..VVV.VVV..."],
	"ranger": ["...JJJJ.....", "..JJJJJJ....", ".JJffffJJ.w.", ".JJfKKfJJnw.", ".JJffffJJ.w.", "..jJJJJj.nw.", ".jJJJJJJj.w.", ".jJJJJJJjnw.", ".jJJJJJJj.w.", "..JJ..JJ....", "..JJ..JJ....", ".jjj..jjj..."],
	"door": ["..DDDD..", ".DwwwwD.", "DwwwwwwD", "DwwwywwD", "DwwwwwwD", "DwwwwwwD", "DwwwwwwD", "DDDDDDDD"],
	"stairs": ["........", "QQ......", "QqQQ....", "QqQqQQ..", "QqQqQqQQ", "QqQqQqQq", "QqQqQqQq", "QQQQQQQQ"],
	"grave": ["...KKKKKK...", "..KqqqqqqK..", ".KqqqqqqqqK.", ".KqqqKKqqqK.", ".KqKKKKKKqK.", ".KqKKKKKKqK.", ".KqqqKKqqqK.", ".KqqqKKqqqK.", ".KqqqqqqqqK.", ".KQqqqqqqQK.", "..oooooooo..", ".oooooooooo."],
	"gem": ["...cc...", "..cccc..", ".cvvvvc.", "cvvvvvvc", ".Vvvvvv.", "..VvvV..", "...VV...", "........"],
	"shield": [".gyyyyg.", "gyyyyyyg", "gyyggyyg", "gyyggyyg", "gyyyyyyg", ".gyyyyg.", "..gyyg..", "...gg..."],
	"fire": ["...y....", "...yy...", "..yFy...", "..yFFy..", ".yFFRFy.", ".yFRRFy.", ".FFRRFF.", "..FFFF.."],
	"pick": ["m......m", ".m....m.", "..mmmm..", "...MM...", "...ww...", "...ww...", "...ww...", "...ww..."],
	"bag": ["...KK...", "..wKKw..", ".wwwwww.", "wwwwwwww", "wwCCCCww", "wwwwwwww", ".wwwwww.", "..wwww.."],
	"die": ["KKKKKKKK", "KnnnnnnK", "KnKnnKnK", "KnnnnnnK", "KnnnKnnK", "KnnnnnnK", "KnKnnKnK", "KKKKKKKK"],
	"scroll": ["..nnnn..", ".nKKKKn.", "nnnnnnnn", "nKKKKKKn", "nnnnnnnn", "nKKKKKKn", ".nKKKKn.", "..nnnn.."],
}
var SPRITE_PAL := {
	"K": Color8(43, 43, 43), "g": Color8(205, 161, 42), "y": Color8(244, 221, 132),
	"s": Color8(143, 111, 20), "r": Color8(194, 49, 66), "p": Color8(236, 111, 128),
	"G": Color8(90, 168, 108), "E": Color8(53, 96, 64), "B": Color8(22, 33, 15),
	"W": Color8(255, 255, 255), "n": Color8(233, 227, 209), "m": Color8(194, 198, 202),
	"M": Color8(123, 129, 134), "o": Color8(111, 86, 56), "O": Color8(84, 64, 31),
	"w": Color8(154, 101, 49), "l": Color8(36, 26, 14), "d": Color8(58, 42, 26),
	"f": Color8(227, 180, 140), "u": Color8(46, 90, 140), "U": Color8(29, 58, 92),
	"b": Color8(107, 74, 42), "D": Color8(74, 51, 32), "q": Color8(184, 176, 160),
	"Q": Color8(106, 98, 88),
	"a": Color8(154, 164, 174), "A": Color8(95, 106, 117),
	"v": Color8(106, 74, 160), "V": Color8(63, 40, 112),
	"J": Color8(63, 125, 79), "j": Color8(39, 77, 51),
	"F": Color8(232, 134, 58), "R": Color8(176, 48, 31), "c": Color8(94, 200, 224),
	"C": Color8(192, 138, 74),
}

# ---- Localization (en, bg, fr, de) ----
const LANGS := ["en", "bg", "fr", "de"]
const STRINGS := {
	"ui_play": ["Play", "Играй", "Jouer", "Spielen"],
	"ui_settings": ["Settings", "Настройки", "Paramètres", "Einstellungen"],
	"ui_choose_slot": ["Choose a slot", "Избери слот", "Choisir un slot", "Slot wählen"],
	"ui_back": ["Back", "Назад", "Retour", "Zurück"],
	"ui_slot": ["Slot", "Слот", "Slot", "Slot"],
	"ui_new_game": ["+ New game", "+ Нова игра", "+ Nouvelle partie", "+ Neues Spiel"],
	"ui_choose_class": ["Choose a class", "Избери клас", "Choisir une classe", "Klasse wählen"],
	"cls_knight_name": ["KNIGHT", "РИЦАР", "CHEVALIER", "RITTER"],
	"cls_knight_desc": ["Free kill 1/floor", "Безплатно убийство 1/етаж", "Kill gratuit 1/étage", "Gratis-Kill 1/Ebene"],
	"cls_mage_name": ["MAGE", "МАГЬОСНИК", "MAGE", "MAGIER"],
	"cls_mage_desc": ["Firebolt · 3/floor, range 4", "Firebolt · 3/етаж, обхват 4", "Firebolt · 3/étage, portée 4", "Firebolt · 3/Ebene, Reichw. 4"],
	"cls_ranger_name": ["RANGER", "РЕЙНДЖЪР", "RÔDEUR", "WALDLÄUFER"],
	"cls_ranger_desc": ["+1 step · break wall 1/floor", "+1 стъпка · чупи стена 1/етаж", "+1 pas · casse mur 1/étage", "+1 Schritt · Wand 1/Ebene"],
	"ui_roll": ["Roll die", "Хвърли зар", "Lancer le dé", "Würfeln"],
	"ui_enemies": ["Enemies move", "Враговете мърдат", "Ennemis bougent", "Gegner ziehen"],
	"ui_bag": ["Bag", "Раница", "Sac", "Tasche"],
	"ui_inventory": ["Inventory", "Инвентар", "Inventaire", "Inventar"],
	"ui_items": ["Items", "Предмети", "Objets", "Gegenstände"],
	"ui_quest": ["Quest", "Куест", "Quête", "Quest"],
	"inv_no_items": ["No items yet", "Още няма предмети", "Aucun objet", "Keine Gegenstände"],
	"inv_no_quest": ["No active quest", "Няма активен куест", "Aucune quête", "Kein Auftrag"],
	"ui_continue": ["Continue", "Продължи", "Continuer", "Weiter"],
	"shop_hdr_buy": ["Shop", "Магазин", "Boutique", "Laden"],
	"shop_hdr_quest": ["Quest — choose 1", "Мисия — избери 1", "Quête — choisir 1", "Auftrag — wähle 1"],
	"shop_owned": ["owned", "купено", "acheté", "gekauft"],
	"shop_potion_t": ["Health potion", "Отвара за живот", "Potion de vie", "Heiltrank"],
	"shop_potion_b": ["Restore 5 HP", "Възстанови 5 HP", "Rend 5 PV", "Stellt 5 HP her"],
	"shop_elixir_t": ["Elixir", "Еликсир", "Élixir", "Elixier"],
	"shop_elixir_b": ["Full heal", "Пълно лечение", "Soin complet", "Volle Heilung"],
	"shop_maxhp_t": ["Heart crystal", "Кристал сърце", "Cristal de cœur", "Herzkristall"],
	"shop_maxhp_b": ["+2 Max HP (permanent)", "+2 Max HP (постоянно)", "+2 PV max (permanent)", "+2 Max-HP (dauerhaft)"],
	"shop_tome_t": ["Tome of insight", "Том на прозрението", "Tome du savoir", "Buch der Einsicht"],
	"shop_tome_b": ["+3 XP toward level", "+3 XP към ниво", "+3 XP vers le niveau", "+3 XP zum Level"],
	"quest_survive": ["Reach Floor %d alive", "Стигни Етаж %d жив", "Atteindre l'étage %d vivant", "Erreiche Ebene %d lebend"],
	"quest_gold": ["Collect %d gold", "Събери %d злато", "Récolte %d or", "Sammle %d Gold"],
	"quest_rew_g": ["Reward: %d gold", "Награда: %d злато", "Récompense : %d or", "Belohnung: %d Gold"],
	"quest_rew_x": ["Reward: %d XP", "Награда: %d XP", "Récompense : %d XP", "Belohnung: %d XP"],
	"quest_rew_gx": ["Reward: %d gold + %d XP", "Награда: %d злато + %d XP", "Récompense : %d or + %d XP", "Belohnung: %d Gold + %d XP"],
	"quest_pen_g": ["Penalty: -%d gold", "Пенълти: -%d злато", "Pénalité : -%d or", "Strafe: -%d Gold"],
	"quest_pen_h": ["Penalty: -%d HP", "Пенълти: -%d HP", "Pénalité : -%d PV", "Strafe: -%d HP"],
	"quest_deadline": ["Deadline: Floor %d", "Срок: Етаж %d", "Limite : Étage %d", "Frist: Ebene %d"],
	"quest_penalized": ["Quest failed! %s", "Мисия провалена! %s", "Quête ratée ! %s", "Auftrag verfehlt! %s"],
	"inv_quest_active": ["Active: %s", "Активна: %s", "Active : %s", "Aktiv: %s"],
	"inv_xp": ["XP %d/%d", "XP %d/%d", "XP %d/%d", "XP %d/%d"],
	"log_shop": ["A merchant! Spend your gold, take a quest.", "Търговец! Похарчи злато, вземи мисия.", "Un marchand ! Dépensez, prenez une quête.", "Ein Händler! Gib Gold aus, nimm einen Auftrag."],
	"log_levelup": ["Level up! Now Lv %d, +2 Max HP.", "Ниво нагоре! Вече Lv %d, +2 Max HP.", "Niveau %d ! +2 PV max.", "Levelaufstieg! Jetzt Lv %d, +2 Max-HP."],
	"log_bought": ["Bought %s.", "Купи %s.", "Acheté %s.", "%s gekauft."],
	"log_quest_take": ["Quest taken: %s", "Мисия: %s", "Quête prise : %s", "Auftrag: %s"],
	"log_quest_done": ["Quest done! %s", "Мисия готова! %s", "Quête finie ! %s", "Auftrag erledigt! %s"],
	"log_quest_fail": ["Quest expired.", "Мисията изтече.", "Quête expirée.", "Auftrag abgelaufen."],
	"ui_you_died": ["YOU DIED", "ЗАГИНА", "VOUS ÊTES MORT", "GESTORBEN"],
	"ui_restart": ["Restart from Floor 1", "Отначало (Етаж 1)", "Recommencer (Étage 1)", "Neustart (Ebene 1)"],
	"death_reached": ["Reached Floor %d · %d GP", "Стигна Етаж %d · %d GP", "Étage %d atteint · %d GP", "Ebene %d erreicht · %d GP"],
	"death_hint": ["back to Floor 1 · 0 GP · base HP", "обратно на Етаж 1 · 0 GP · базово HP", "retour Étage 1 · 0 GP · PV de base", "zurück zu Ebene 1 · 0 GP · Basis-HP"],
	"ui_exit": ["Exit", "Излез", "Quitter", "Verlassen"],
	"ui_language": ["Language", "Език", "Langue", "Sprache"],
	"ui_swap": ["Swap sides", "Размени страните", "Inverser les côtés", "Seiten tauschen"],
	"ui_save_exit": ["Save & Exit", "Запази и излез", "Sauver & Quitter", "Speichern & Raus"],
	"ui_howto": ["How to play", "Как се играе", "Comment jouer", "Anleitung"],
	"ui_skip": ["Skip", "Пропусни", "Passer", "Überspringen"],
	"ui_next": ["Next", "Напред", "Suivant", "Weiter"],
	"tut_goal_t": ["Goal", "Цел", "Objectif", "Ziel"],
	"tut_goal_b": ["Reach the exit door to descend one floor. Survive as deep as you can!", "Стигни изхода, за да слезеш един етаж по-надолу. Оцелей възможно най-дълбоко!", "Atteignez la sortie pour descendre d'un étage. Survivez le plus profond possible !", "Erreiche den Ausgang, um eine Ebene tiefer zu gehen. Überlebe so tief wie möglich!"],
	"tut_roll_t": ["Roll the die", "Хвърли зара", "Lancez le dé", "Würfeln"],
	"tut_roll_b": ["Tap Roll die. The number is your steps. Odd = diagonal, Even = straight.", "Натисни Roll die. Числото е стъпките ти. Нечетно = диагонал, четно = право.", "Appuyez sur Roll die. Le nombre = vos pas. Impair = diagonale, pair = tout droit.", "Tippe Roll die. Die Zahl sind deine Schritte. Ungerade = diagonal, gerade = gerade."],
	"tut_move_t": ["Move", "Движение", "Déplacement", "Bewegen"],
	"tut_move_b": ["Tap a green spot to move there. Hit a wall and your path turns and continues.", "Цъкни зелена точка, за да отидеш там. Удариш ли стена, пътят завива и продължава.", "Touchez un point vert pour y aller. Un mur ? Le chemin tourne et continue.", "Tippe einen grünen Punkt an. Triffst du eine Wand, dreht der Weg ab."],
	"tut_pick_t": ["Pickups", "Предмети", "Objets", "Gegenstände"],
	"tut_pick_b": ["Coin and chest give gold. Heart heals. Trap steals gold. Grab the good, avoid the bad.", "Монета и сандък дават злато. Сърце лекува. Капан краде злато. Взимай доброто, пази се от лошото.", "Pièce et coffre donnent de l'or. Cœur soigne. Piège vole de l'or.", "Münze und Truhe geben Gold. Herz heilt. Falle stiehlt Gold."],
	"tut_enemy_t": ["Enemies", "Врагове", "Ennemis", "Gegner"],
	"tut_enemy_b": ["Cross an enemy to kill it (you take a little damage). Enemies chase you and clash onto you — watch the red trail.", "Мини през враг, за да го убиеш (взимаш малко щета). Враговете те преследват и се хвърлят отгоре ти — гледай червената следа.", "Traversez un ennemi pour le tuer (petits dégâts). Les ennemis vous poursuivent — attention à la traînée rouge.", "Laufe durch einen Gegner, um ihn zu töten (etwas Schaden). Gegner jagen dich — achte auf die rote Spur."],
	"tut_level_t": ["Level up", "Ниво", "Niveau", "Levelaufstieg"],
	"tut_level_b": ["Clearing floors and quests earns XP (the gem). Each level up gives +2 Max HP.", "Етажите и мисиите дават XP (гемът). Всяко ниво нагоре дава +2 Max HP.", "Étages et quêtes donnent de l'XP (la gemme). Chaque niveau : +2 PV max.", "Ebenen und Aufträge geben XP (Edelstein). Jeder Aufstieg: +2 Max-HP."],
	"tut_class_t": ["Your class", "Твоят клас", "Ta classe", "Deine Klasse"],
	"tut_class_b": ["Use your class power with its button (shield / firebolt / break wall). At 0 HP you restart from Floor 1.", "Ползвай силата на класа с бутона (щит / firebolt / чупене на стена). При 0 HP почваш от Етаж 1.", "Utilisez le pouvoir de classe (bouclier / firebolt / mur). À 0 PV, retour à l'étage 1.", "Nutze deine Klassenkraft (Schild / Firebolt / Wand). Bei 0 HP zurück zu Ebene 1."],
	"tut_merchant_t": ["Merchant", "Търговец", "Marchand", "Händler"],
	"tut_merchant_b": ["Every few floors a merchant appears (it is not a floor).", "На всеки няколко етажа се появява търговец (не е етаж).", "Tous les quelques étages, un marchand apparaît (ce n'est pas un étage).", "Alle paar Ebenen erscheint ein Händler (keine Ebene)."],
	"tut_buy_t": ["Buy items", "Купи предмети", "Acheter", "Kaufen"],
	"tut_buy_b": ["Spend gold on potions, healing and permanent upgrades.", "Харчиш злато за отвари, лечение и постоянни ъпгрейди.", "Dépensez de l'or en potions, soins et améliorations.", "Gib Gold für Tränke, Heilung und Upgrades aus."],
	"tut_quest_t": ["Quests", "Мисии", "Quêtes", "Aufträge"],
	"tut_quest_b": ["Take 1 of 2 quests. Complete it for a reward, fail it for a penalty.", "Взимаш 1 от 2 мисии. Изпълниш ли я — награда; провалиш ли я — пенълти.", "Prenez 1 quête sur 2. Réussie = récompense, ratée = pénalité.", "Nimm 1 von 2 Aufträgen. Erfüllt = Belohnung, verfehlt = Strafe."],
	"ui_music": ["Music", "Музика", "Musique", "Musik"],
	"ui_sound": ["Sound", "Звук", "Son", "Ton"],
	"hud_level": ["Floor %d", "Етаж %d", "Étage %d", "Ebene %d"],
	"mode_diag": ["diagonal", "диагонал", "diagonale", "diagonal"],
	"mode_straight": ["straight", "право", "droite", "gerade"],
	"ab_shield_ready": ["Shield: ready", "Щит: готов", "Bouclier: prêt", "Schild: bereit"],
	"ab_shield_used": ["Shield: used", "Щит: ползван", "Bouclier: usé", "Schild: benutzt"],
	"ab_magic": ["Firebolt %d", "Firebolt %d", "Firebolt %d", "Firebolt %d"],
	"ab_target": ["  •target•", "  •цел•", "  •cible•", "  •Ziel•"],
	"ab_wall": ["Break wall (1)", "Пробий стена (1)", "Percer mur (1)", "Wand brechen (1)"],
	"ab_wall_target": ["Break: target", "Пробий: цел", "Percer: cible", "Brechen: Ziel"],
	"ab_wall_used": ["Wall: used", "Стена: ползвана", "Mur: usé", "Wand: benutzt"],
	"log_new_level": ["Floor %d. Roll to begin.", "Етаж %d. Хвърли зар за да започнеш.", "Étage %d. Lancez le dé.", "Ebene %d. Würfle zum Start."],
	"log_resume": ["Floor %d. Roll to continue.", "Етаж %d. Хвърли зар за да продължиш.", "Étage %d. Lancez pour continuer.", "Ebene %d. Würfle weiter."],
	"log_no_move": ["Nowhere to go. Roll again.", "Няма накъде. Хвърли пак.", "Aucun chemin. Relancez.", "Kein Weg. Nochmal würfeln."],
	"log_rolled": ["Rolled %d (%s). Choose where.", "Хвърли %d (%s). Избери накъде.", "%d (%s). Choisissez où.", "%d (%s). Wähle wohin."],
	"log_move": ["Move %s, %d steps.", "Ход %s, %d стъпки.", "Déplacement %s, %d pas.", "Zug %s, %d Schritte."],
	"log_gp": [" %+d GP.", " %+d GP.", " %+d GP.", " %+d GP."],
	"log_hp": [" %+d HP.", " %+d HP.", " %+d HP.", " %+d HP."],
	"log_win": ["Reached the exit! Floor %d begins.", "Стигна изхода! Етаж %d започва.", "Sortie atteinte ! Étage %d.", "Ausgang erreicht! Ebene %d."],
	"log_died": ["You died! Floor restarts.", "Загина! Етажът започва наново.", "Vous êtes mort ! Étage relancé.", "Gestorben! Ebene neu."],
	"log_shield": ["Shield! Killed an enemy safely.", "Щит! Уби враг без щета.", "Bouclier ! Ennemi tué sans dégât.", "Schild! Gegner ohne Schaden."],
	"log_magic": ["Firebolt! Killed an enemy at range.", "Firebolt! Уби враг от разстояние.", "Firebolt ! Ennemi tué à distance.", "Firebolt! Gegner aus Distanz."],
	"log_drill": ["Broke a hole in the wall!", "Проби дупка в стената!", "Trou percé dans le mur !", "Loch in die Wand gebrochen!"],
	"dir_right": ["right", "надясно", "droite", "rechts"],
	"dir_left": ["left", "наляво", "gauche", "links"],
	"dir_down": ["down", "надолу", "bas", "unten"],
	"dir_up": ["up", "нагоре", "haut", "oben"],
	"dir_dr": ["down-right", "долу-дясно", "bas-droite", "unten-rechts"],
	"dir_ur": ["up-right", "горе-дясно", "haut-droite", "oben-rechts"],
	"dir_dl": ["down-left", "долу-ляво", "bas-gauche", "unten-links"],
	"dir_ul": ["up-left", "горе-ляво", "haut-gauche", "oben-links"],
}

const TUT_GENERAL := [
	{"i": ["door"], "t": "tut_goal_t", "b": "tut_goal_b"},
	{"i": ["die"], "t": "tut_roll_t", "b": "tut_roll_b"},
	{"i": ["knight"], "t": "tut_move_t", "b": "tut_move_b"},
	{"i": ["coin", "heart", "chest", "trap"], "t": "tut_pick_t", "b": "tut_pick_b"},
	{"i": ["enemy"], "t": "tut_enemy_t", "b": "tut_enemy_b"},
	{"i": ["gem"], "t": "tut_level_t", "b": "tut_level_b"},
	{"i": ["shield"], "t": "tut_class_t", "b": "tut_class_b"},
]
const TUT_SHOP := [
	{"i": ["bag"], "t": "tut_merchant_t", "b": "tut_merchant_b"},
	{"i": ["coin"], "t": "tut_buy_t", "b": "tut_buy_b"},
	{"i": ["scroll"], "t": "tut_quest_t", "b": "tut_quest_b"},
]

# Shop offers 3 random items from this pool. "eff" handled in _buy_item.
const SHOP_ITEMS := [
	{"id": "potion", "icon": "heart", "t": "shop_potion_t", "b": "shop_potion_b", "cost": 8},
	{"id": "elixir", "icon": "heart", "t": "shop_elixir_t", "b": "shop_elixir_b", "cost": 14},
	{"id": "maxhp", "icon": "gem", "t": "shop_maxhp_t", "b": "shop_maxhp_b", "cost": 18},
	{"id": "tome", "icon": "scroll", "t": "shop_tome_t", "b": "shop_tome_b", "cost": 12},
]

enum S { MENU, SLOTS, CLASS, SETTINGS, PLAYING, INVENTORY }

# ---- Game state ----
var state := S.MENU
var locale := "en"
var current_slot := -1
var level := 1
var hero_xp := 0
var next_shop_floor := 0          # floor at which the merchant next appears
var active_quest := {}            # {} = none; see _open_shop for shape
var shop_offer: Array = []        # 3 item ids currently offered
var shop_bought: Dictionary = {}  # item id -> true once bought this visit
var shop_quests: Array = []       # 2 quest dicts offered this visit
var shop_quest_pick := -1         # index of quest picked this visit (visit-local)
var shop_tut_seen := false
var pending_advance := false
var die_value := 1
var die_angle := 0.0
var show_die := false

# ---- Hero class + abilities ----
var hero_class := "knight"
var knight_shield := false        # free enemy kill available this level
var wall_pass_available := false  # ranger: drill a wall once per level
var drilling := false
var mage_casts := 0               # mage: ranged kills left this level
var mage_turn_cast := false       # mage: may cast once after each roll
var casting := false

var player := {}
var current_n := 0
var diagonal := false
var options: Array[Vector2i] = []
var option_paths: Dictionary = {}
var awaiting_move := false
var path: Array[Vector2i] = []
var entities: Array = []
var walls: Dictionary = {}
var entrance_cell := Vector2i(0, 0)
var exit_cell := Vector2i(COLS - 1, ROWS - 1)
var spinning := false
var game_over := false
var log_lines: Array[String] = []

# ---- UI nodes ----
var ui_theme: Theme
var game_ui: Control
var menu_ui: Control
var slots_ui: Control
var class_ui: Control
var settings_ui: Control
var hp_label: Label
var gold_label: Label
var level_label: Label
var floor_label: Label
var hero_level := 1
var ability_icon_tex: Dictionary = {}
var roll_button: Button
var roll_result_label: Label
var settings_ingame_btn: Button
var ability_button: Button
var log_label: Label
var log_panel: Panel
var die_pos := Vector2(585, 908)
var layout_swapped := false
var slot_buttons: Array = []
var del_buttons: Array = []
# audio
var music_player: AudioStreamPlayer
var sfx_players: Array = []
var sfx_idx := 0
var sfx_bank: Dictionary = {}
var music_on := true
var sfx_on := true
var music_btn: Button
var sfx_btn: Button
# static-text controls that get re-labelled on language change
var play_btn: Button
var settings_btn: Button
var slots_title: Label
var slots_back: Button
var class_title: Label
var class_back: Button
var settings_title: Label
var lang_title: Label
var settings_back: Button
var swap_btn: Button
var save_exit_btn: Button
var howto_btn: Button
var settings_return := S.MENU
var tutorial_seen := false
# tutorial overlay
var tutorial_ui: Control
var tut_dots_holder: Control
var tut_icon_holder: Control
var tut_title: Label
var tut_body: Label
var tut_skip_btn: Button
var tut_next_btn: Button
var tut_steps: Array = []
var tut_index := 0
# shop overlay
var shop_ui: Control
var shop_gold_label: Label
var shop_item_rows: Array = []      # [{root, name, desc, price}] x3
var shop_quest_cards: Array = []    # [{root, title, body}] x2
var shop_continue_btn: Button
var shop_buy_hdr: Label
var shop_quest_hdr: Label
# death overlay
var death_ui: Control
var death_title: Label
var death_summary: Label
var death_restart_btn: Button
var death_hint: Label
# inventory
var inv_btn: Button
var inventory_ui: Control
var inv_title: Label
var inv_hero_sprite: TextureRect
var inv_hero_name: Label
var inv_hero_stats: Label
var inv_items_title: Label
var inv_items_label: Label
var inv_quest_title: Label
var inv_quest_label: Label
# slot card pieces
var slot_sprites: Array = []
var slot_names: Array = []
var slot_metas: Array = []
var slot_hpbgs: Array = []
var slot_hpfills: Array = []
var slot_newlabels: Array = []
# class card pieces
var class_cards: Array = []
var class_name_labels: Array = []
var class_desc_labels: Array = []


func _ready() -> void:
	randomize()
	_load_settings()
	_build_ui()
	_build_audio()
	_apply_language()
	_check_version_wipe()
	_show_menu()


# Wipe local save slots whenever the build version changes.
func _check_version_wipe() -> void:
	var stored := ""
	if FileAccess.file_exists("user://version.txt"):
		var f := FileAccess.open("user://version.txt", FileAccess.READ)
		if f:
			stored = f.get_as_text().strip_edges()
			f.close()
	if stored == GAME_VERSION:
		return
	var d := DirAccess.open("user://")
	if d:
		for i in 3:
			var fname := "slot_%d.save" % i
			if d.file_exists(fname):
				d.remove(fname)
	var wf := FileAccess.open("user://version.txt", FileAccess.WRITE)
	if wf:
		wf.store_string(GAME_VERSION)
		wf.close()


# =====================================================================
#  UI
# =====================================================================
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Handjet pixel font (covers Latin + Cyrillic + accents consistently)
	var base_font: FontFile = load("res://fonts/Handjet.ttf")
	var pf := FontVariation.new()
	pf.base_font = base_font
	pf.variation_opentype = {"wght": 500}
	ui_theme = Theme.new()
	ui_theme.default_font = pf
	ui_theme.default_font_size = 26

	# ---- Game screen ----
	game_ui = Control.new()
	game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game_ui.theme = ui_theme
	layer.add_child(game_ui)

	# top HUD — icons in a row, Floor on the right
	_make_icon(game_ui, Vector2(16, 30), "heart", 4)
	hp_label = _make_label(game_ui, Vector2(54, 24), Vector2(140, 46), 28, C_RED)
	hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_icon(game_ui, Vector2(200, 30), "coin", 4)
	gold_label = _make_label(game_ui, Vector2(238, 24), Vector2(110, 46), 28, C_GOLD)
	gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_make_icon(game_ui, Vector2(356, 30), "gem", 4)
	level_label = _make_label(game_ui, Vector2(394, 24), Vector2(90, 46), 28, C_CREAM)
	level_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_label = _make_label(game_ui, Vector2(490, 24), Vector2(214, 46), 28, C_CREAM)
	floor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	floor_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	ability_icon_tex = {
		"knight": _sprite_texture("shield", 3),
		"mage": _sprite_texture("fire", 3),
		"ranger": _sprite_texture("pick", 3),
	}

	ability_button = _make_button(game_ui, "", Vector2.ZERO, Vector2(10, 10))
	ability_button.add_theme_font_size_override("font_size", 24)
	ability_button.pressed.connect(_on_ability)

	roll_button = _make_button(game_ui, "", Vector2.ZERO, Vector2(10, 10))
	roll_button.add_theme_font_size_override("font_size", 32)
	roll_button.pressed.connect(_on_roll)

	roll_result_label = _make_label(game_ui, Vector2.ZERO, Vector2(10, 10), 24, C_CREAM)
	roll_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	roll_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	inv_btn = _make_button(game_ui, "", Vector2.ZERO, Vector2(10, 10), "secondary")
	inv_btn.icon = _sprite_texture("bag", 4)
	inv_btn.add_theme_font_size_override("font_size", 24)
	inv_btn.pressed.connect(_show_inventory)

	settings_ingame_btn = _make_button(game_ui, "", Vector2.ZERO, Vector2(10, 10), "secondary")
	settings_ingame_btn.add_theme_font_size_override("font_size", 24)
	settings_ingame_btn.pressed.connect(_open_ingame_settings)

	log_panel = Panel.new()
	var lsb := StyleBoxFlat.new()
	lsb.bg_color = Color8(42, 36, 32)
	lsb.set_border_width_all(2)
	lsb.border_color = Color8(106, 90, 68)
	lsb.set_corner_radius_all(6)
	log_panel.add_theme_stylebox_override("panel", lsb)
	game_ui.add_child(log_panel)
	log_label = _make_label(log_panel, Vector2(14, 12), Vector2(440, 150), 22, C_CREAM)
	log_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_layout_bottom()

	# ---- Main menu screen ----
	menu_ui = Control.new()
	menu_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_ui.theme = ui_theme
	layer.add_child(menu_ui)
	var title := _make_label(menu_ui, Vector2(40, 380), Vector2(640, 170), 56, C_ACCENT)
	title.text = "PAPER\nDUNGEON"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	play_btn = _make_button(menu_ui, "", Vector2(160, 630), Vector2(400, 120), "primary")
	play_btn.add_theme_font_size_override("font_size", 40)
	play_btn.pressed.connect(func(): _sfx("button"); _show_slots())
	settings_btn = _make_button(menu_ui, "", Vector2(210, 780), Vector2(300, 90), "secondary")
	settings_btn.add_theme_font_size_override("font_size", 30)
	settings_btn.pressed.connect(func(): _sfx("button"); _show_settings())

	# ---- Slot select screen ----
	slots_ui = Control.new()
	slots_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	slots_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slots_ui.theme = ui_theme
	layer.add_child(slots_ui)
	slots_back = _make_button(slots_ui, "‹", Vector2(30, 30), Vector2(72, 72), "tertiary")
	slots_back.add_theme_font_size_override("font_size", 48)
	slots_back.pressed.connect(func(): _sfx("button"); _show_menu())
	slots_title = _make_label(slots_ui, Vector2(60, 42), Vector2(600, 70), 40, C_ACCENT)
	slots_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_buttons = []
	del_buttons = []
	slot_sprites = []
	slot_names = []
	slot_metas = []
	slot_hpbgs = []
	slot_hpfills = []
	slot_newlabels = []
	for i in 3:
		var cy := 385 + i * 215
		var card := _make_button(slots_ui, "", Vector2(40, cy), Vector2(640, 195), "secondary")
		card.pressed.connect(_on_slot_pressed.bind(i))
		slot_buttons.append(card)
		var spr := TextureRect.new()
		spr.position = Vector2(22, 50)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(spr)
		slot_sprites.append(spr)
		var nm := _make_label(card, Vector2(150, 26), Vector2(400, 44), 30, C_ACCENT)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_names.append(nm)
		var mt := _make_label(card, Vector2(150, 78), Vector2(400, 40), 24, C_CREAM)
		mt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_metas.append(mt)
		slot_hpbgs.append(_make_rect(card, Vector2(150, 130), Vector2(250, 18), Color8(58, 34, 34)))
		slot_hpfills.append(_make_rect(card, Vector2(150, 130), Vector2(250, 18), C_RED))
		var nl := _make_label(card, Vector2(0, 74), Vector2(640, 48), 30, C_MUTED)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_newlabels.append(nl)
		var del := _make_button(card, "x", Vector2(560, 20), Vector2(60, 60), "danger")
		del.add_theme_font_size_override("font_size", 30)
		del.pressed.connect(_delete_slot.bind(i))
		del_buttons.append(del)

	# ---- Class select screen ----
	class_ui = Control.new()
	class_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	class_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_ui.theme = ui_theme
	layer.add_child(class_ui)
	class_back = _make_button(class_ui, "‹", Vector2(30, 30), Vector2(72, 72), "tertiary")
	class_back.add_theme_font_size_override("font_size", 48)
	class_back.pressed.connect(func(): _sfx("button"); _show_slots())
	class_title = _make_label(class_ui, Vector2(60, 42), Vector2(600, 70), 40, C_ACCENT)
	class_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_cards = []
	class_name_labels = []
	class_desc_labels = []
	var classes := ["knight", "mage", "ranger"]
	var class_hp := [10, 6, 8]
	for i in 3:
		var cy := 380 + i * 215
		var card := _make_button(class_ui, "", Vector2(40, cy), Vector2(640, 195), "primary")
		card.pressed.connect(_choose_class.bind(classes[i]))
		class_cards.append(card)
		var spr := TextureRect.new()
		spr.texture = _sprite_texture(classes[i], 8)
		spr.position = Vector2(22, 50)
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		spr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(spr)
		var nm := _make_label(card, Vector2(150, 22), Vector2(460, 44), 30, C_ACCENT)
		nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
		class_name_labels.append(nm)
		var pips: int = class_hp[i] / 2
		for pi in pips:
			_make_rect(card, Vector2(150 + pi * 30, 82), Vector2(22, 22), C_RED)
		var ds := _make_label(card, Vector2(150, 118), Vector2(470, 60), 22, C_CREAM)
		ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ds.mouse_filter = Control.MOUSE_FILTER_IGNORE
		class_desc_labels.append(ds)

	# ---- Settings screen ----
	settings_ui = Control.new()
	settings_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_ui.theme = ui_theme
	layer.add_child(settings_ui)
	settings_back = _make_button(settings_ui, "‹", Vector2(30, 30), Vector2(72, 72), "tertiary")
	settings_back.add_theme_font_size_override("font_size", 48)
	settings_back.pressed.connect(_settings_back)
	settings_title = _make_label(settings_ui, Vector2(60, 42), Vector2(600, 70), 40, C_ACCENT)
	settings_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lang_title = _make_label(settings_ui, Vector2(40, 118), Vector2(640, 46), 30, C_CREAM)
	lang_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var lang_names := ["English", "Български", "Français", "Deutsch"]
	for i in 4:
		var col := i % 2
		var row := i / 2
		var lb := _make_button(settings_ui, lang_names[i], Vector2(90 + col * 290, 172 + row * 116), Vector2(270, 100), "secondary")
		lb.add_theme_font_size_override("font_size", 28)
		lb.pressed.connect(_set_language.bind(LANGS[i]))
	music_btn = _make_button(settings_ui, "", Vector2(90, 408), Vector2(540, 76), "secondary")
	music_btn.add_theme_font_size_override("font_size", 30)
	music_btn.pressed.connect(_toggle_music)
	sfx_btn = _make_button(settings_ui, "", Vector2(90, 492), Vector2(540, 76), "secondary")
	sfx_btn.add_theme_font_size_override("font_size", 30)
	sfx_btn.pressed.connect(_toggle_sfx)
	swap_btn = _make_button(settings_ui, "", Vector2(90, 576), Vector2(540, 76), "secondary")
	swap_btn.add_theme_font_size_override("font_size", 30)
	swap_btn.pressed.connect(_toggle_swap)
	howto_btn = _make_button(settings_ui, "", Vector2(90, 660), Vector2(540, 76), "secondary")
	howto_btn.add_theme_font_size_override("font_size", 30)
	howto_btn.pressed.connect(func(): _sfx("button"); _start_tutorial(TUT_GENERAL + TUT_SHOP))
	save_exit_btn = _make_button(settings_ui, "", Vector2(150, 766), Vector2(420, 86), "primary")
	save_exit_btn.add_theme_font_size_override("font_size", 30)
	save_exit_btn.pressed.connect(_exit_to_menu)
	save_exit_btn.visible = false

	# ---- Death overlay ----
	death_ui = Control.new()
	death_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	death_ui.theme = ui_theme
	death_ui.visible = false
	layer.add_child(death_ui)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.02, 0.78)
	death_ui.add_child(dim)
	var dpanel := Panel.new()
	dpanel.position = Vector2(160, 380)
	dpanel.size = Vector2(400, 500)
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Color8(33, 29, 24)
	dsb.set_border_width_all(3)
	dsb.border_color = Color8(201, 162, 39)
	dsb.set_corner_radius_all(10)
	dpanel.add_theme_stylebox_override("panel", dsb)
	death_ui.add_child(dpanel)
	var grave := TextureRect.new()
	grave.texture = _sprite_texture("grave", 8)
	grave.position = Vector2(152, 30)
	grave.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	grave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dpanel.add_child(grave)
	death_title = _make_label(dpanel, Vector2(0, 150), Vector2(400, 60), 48, Color8(224, 86, 106))
	death_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_summary = _make_label(dpanel, Vector2(0, 225), Vector2(400, 40), 24, C_MUTED)
	death_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_restart_btn = _make_button(dpanel, "", Vector2(40, 300), Vector2(320, 90), "primary")
	death_restart_btn.add_theme_font_size_override("font_size", 30)
	death_restart_btn.pressed.connect(_restart_run)
	death_hint = _make_label(dpanel, Vector2(0, 410), Vector2(400, 30), 18, C_MUTED)
	death_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ---- Inventory screen ----
	inventory_ui = Control.new()
	inventory_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inventory_ui.theme = ui_theme
	layer.add_child(inventory_ui)
	var iback := _make_button(inventory_ui, "‹", Vector2(30, 30), Vector2(72, 72), "tertiary")
	iback.add_theme_font_size_override("font_size", 48)
	iback.pressed.connect(func(): _sfx("button"); _show_game())
	inv_title = _make_label(inventory_ui, Vector2(60, 42), Vector2(600, 70), 40, C_ACCENT)
	inv_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var hcard := Panel.new()
	hcard.position = Vector2(40, 170)
	hcard.size = Vector2(640, 170)
	var hsb := StyleBoxFlat.new()
	hsb.bg_color = Color8(42, 36, 32)
	hsb.set_border_width_all(2)
	hsb.border_color = Color8(106, 90, 68)
	hsb.set_corner_radius_all(6)
	hcard.add_theme_stylebox_override("panel", hsb)
	inventory_ui.add_child(hcard)
	inv_hero_sprite = TextureRect.new()
	inv_hero_sprite.position = Vector2(24, 37)
	inv_hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	inv_hero_sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hcard.add_child(inv_hero_sprite)
	inv_hero_name = _make_label(hcard, Vector2(150, 24), Vector2(460, 44), 30, C_ACCENT)
	inv_hero_stats = _make_label(hcard, Vector2(150, 74), Vector2(470, 90), 24, C_CREAM)
	inv_items_title = _make_label(inventory_ui, Vector2(50, 380), Vector2(620, 44), 30, C_ACCENT)
	inv_items_label = _make_label(inventory_ui, Vector2(50, 434), Vector2(620, 220), 24, C_CREAM)
	inv_items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_items_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	inv_quest_title = _make_label(inventory_ui, Vector2(50, 680), Vector2(620, 44), 30, C_ACCENT)
	inv_quest_label = _make_label(inventory_ui, Vector2(50, 734), Vector2(620, 160), 24, C_CREAM)
	inv_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inv_quest_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	# ---- Tutorial overlay ----
	tutorial_ui = Control.new()
	tutorial_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	tutorial_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	tutorial_ui.theme = ui_theme
	tutorial_ui.visible = false
	layer.add_child(tutorial_ui)
	var tdim := ColorRect.new()
	tdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	tdim.color = Color(0.02, 0.02, 0.02, 0.8)
	tutorial_ui.add_child(tdim)
	var tpanel := Panel.new()
	tpanel.position = Vector2(140, 340)
	tpanel.size = Vector2(440, 600)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color8(33, 29, 24)
	tsb.set_border_width_all(3)
	tsb.border_color = Color8(201, 162, 39)
	tsb.set_corner_radius_all(10)
	tpanel.add_theme_stylebox_override("panel", tsb)
	tutorial_ui.add_child(tpanel)
	tut_dots_holder = Control.new()
	tut_dots_holder.position = Vector2(0, 26)
	tut_dots_holder.size = Vector2(440, 18)
	tut_dots_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tpanel.add_child(tut_dots_holder)
	tut_icon_holder = Control.new()
	tut_icon_holder.position = Vector2(0, 66)
	tut_icon_holder.size = Vector2(440, 100)
	tut_icon_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tpanel.add_child(tut_icon_holder)
	tut_title = _make_label(tpanel, Vector2(0, 192), Vector2(440, 50), 34, C_ACCENT)
	tut_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_body = _make_label(tpanel, Vector2(30, 254), Vector2(380, 190), 24, C_CREAM)
	tut_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tut_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	tut_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tut_skip_btn = _make_button(tpanel, "", Vector2(30, 476), Vector2(130, 88), "tertiary")
	tut_skip_btn.add_theme_font_size_override("font_size", 26)
	tut_skip_btn.pressed.connect(_tut_skip)
	tut_next_btn = _make_button(tpanel, "", Vector2(180, 476), Vector2(230, 88), "primary")
	tut_next_btn.add_theme_font_size_override("font_size", 28)
	tut_next_btn.pressed.connect(_tut_next)

	_build_shop_overlay(layer)


func _build_shop_overlay(layer: CanvasLayer) -> void:
	shop_ui = Control.new()
	shop_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_ui.mouse_filter = Control.MOUSE_FILTER_STOP
	shop_ui.theme = ui_theme
	shop_ui.visible = false
	layer.add_child(shop_ui)
	var sdim := ColorRect.new()
	sdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sdim.color = Color(0.02, 0.02, 0.02, 0.85)
	shop_ui.add_child(sdim)
	var spanel := Panel.new()
	spanel.position = Vector2(40, 110)
	spanel.size = Vector2(640, 1060)
	var ssb := StyleBoxFlat.new()
	ssb.bg_color = Color8(33, 29, 24)
	ssb.set_border_width_all(3)
	ssb.border_color = Color8(201, 162, 39)
	ssb.set_corner_radius_all(10)
	spanel.add_theme_stylebox_override("panel", ssb)
	shop_ui.add_child(spanel)

	_make_icon(spanel, Vector2(32, 30), "bag", 6)
	var stitle := _make_label(spanel, Vector2(96, 34), Vector2(360, 50), 40, C_ACCENT)
	stitle.text = t("tut_merchant_t")
	shop_gold_label = _make_label(spanel, Vector2(400, 42), Vector2(210, 40), 30, C_GOLD)
	shop_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	shop_buy_hdr = _make_label(spanel, Vector2(32, 108), Vector2(576, 34), 24, C_MUTED)

	shop_item_rows = []
	for i in 3:
		var ry := 150 + i * 118
		var row := Panel.new()
		row.position = Vector2(24, ry)
		row.size = Vector2(592, 106)
		var rsb := StyleBoxFlat.new()
		rsb.bg_color = Color8(42, 36, 32)
		rsb.set_border_width_all(2)
		rsb.border_color = Color8(74, 64, 56)
		rsb.set_corner_radius_all(8)
		row.add_theme_stylebox_override("panel", rsb)
		spanel.add_child(row)
		var icon := _make_icon(row, Vector2(20, 21), "heart", 8)
		var nm := _make_label(row, Vector2(104, 14), Vector2(300, 40), 28, C_CREAM)
		var ds := _make_label(row, Vector2(104, 56), Vector2(300, 34), 22, C_MUTED)
		var price := _make_button(row, "", Vector2(430, 20), Vector2(146, 66), "primary")
		price.add_theme_font_size_override("font_size", 26)
		price.pressed.connect(_buy_item.bind(i))
		shop_item_rows.append({"icon": icon, "name": nm, "desc": ds, "price": price})

	shop_quest_hdr = _make_label(spanel, Vector2(32, 520), Vector2(576, 34), 24, C_MUTED)

	shop_quest_cards = []
	for i in 2:
		var card := Button.new()
		card.position = Vector2(24 + i * 300, 562)
		card.size = Vector2(292, 268)
		_style_button(card, "secondary")
		card.pressed.connect(_pick_quest.bind(i))
		spanel.add_child(card)
		var qt := _make_label(card, Vector2(16, 14), Vector2(260, 40), 26, C_ACCENT)
		qt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var qb := _make_label(card, Vector2(16, 60), Vector2(260, 196), 22, C_CREAM)
		qb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		qb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		qb.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		shop_quest_cards.append({"root": card, "title": qt, "body": qb})

	shop_continue_btn = _make_button(spanel, "", Vector2(110, 878), Vector2(420, 96), "primary")
	shop_continue_btn.add_theme_font_size_override("font_size", 32)
	shop_continue_btn.pressed.connect(_close_shop)


func _make_label(parent: Control, pos: Vector2, sz: Vector2, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.size = sz
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _make_button(parent: Control, text: String, pos: Vector2, sz: Vector2, kind := "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", 28)
	_style_button(b, kind)
	parent.add_child(b)
	return b


func _style_button(b: Button, kind := "primary") -> void:
	var bg := Color8(58, 44, 30)
	var border := Color8(201, 162, 39)
	var bw := 3
	var fg := Color8(244, 221, 132)
	match kind:
		"secondary":
			bg = Color8(42, 36, 32); border = Color8(106, 90, 68); bw = 2; fg = Color8(232, 223, 200)
		"tertiary":
			bg = Color8(33, 29, 24); border = Color8(74, 66, 58); bw = 2; fg = Color8(200, 187, 160)
		"danger":
			bg = Color8(42, 22, 22); border = Color8(178, 58, 72); bw = 2; fg = Color8(224, 86, 106)
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_border_width_all(bw)
	sb.border_color = border
	sb.set_corner_radius_all(5)
	var hover: StyleBoxFlat = sb.duplicate()
	hover.bg_color = bg.lightened(0.08)
	var press: StyleBoxFlat = sb.duplicate()
	press.bg_color = bg.darkened(0.15)
	var dis: StyleBoxFlat = sb.duplicate()
	dis.bg_color = Color8(48, 42, 36)
	dis.border_color = Color8(96, 86, 60)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", press)
	b.add_theme_stylebox_override("disabled", dis)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg.lightened(0.15))
	b.add_theme_color_override("font_disabled_color", Color8(140, 128, 104))


func _sprite_texture(sprite_name: String, px: int) -> ImageTexture:
	var map: Array = SPRITES[sprite_name]
	var rows := map.size()
	var cols: int = map[0].length()
	var img := Image.create(cols * px, rows * px, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in rows:
		var row: String = map[y]
		for xx in cols:
			var ch := row[xx]
			if SPRITE_PAL.has(ch):
				var col: Color = SPRITE_PAL[ch]
				for dy in px:
					for dx in px:
						img.set_pixel(xx * px + dx, y * px + dy, col)
	return ImageTexture.create_from_image(img)


func _make_rect(parent: Control, pos: Vector2, sz: Vector2, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(r)
	return r


func _make_icon(parent: Control, pos: Vector2, sprite_name: String, px: int) -> TextureRect:
	var tr := TextureRect.new()
	tr.texture = _sprite_texture(sprite_name, px)
	tr.position = pos
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)
	return tr


# =====================================================================
#  Screens / navigation
# =====================================================================
func _set_screen(s: int) -> void:
	state = s
	menu_ui.visible = (s == S.MENU)
	slots_ui.visible = (s == S.SLOTS)
	class_ui.visible = (s == S.CLASS)
	settings_ui.visible = (s == S.SETTINGS)
	inventory_ui.visible = (s == S.INVENTORY)
	game_ui.visible = (s == S.PLAYING)
	queue_redraw()


func _show_menu() -> void:
	_set_screen(S.MENU)


func _show_slots() -> void:
	_refresh_slots()
	_set_screen(S.SLOTS)


func _show_class() -> void:
	_set_screen(S.CLASS)


func _show_settings() -> void:
	settings_return = S.MENU
	save_exit_btn.visible = false
	_set_screen(S.SETTINGS)


func _open_ingame_settings() -> void:
	_sfx("button")
	settings_return = S.PLAYING
	save_exit_btn.visible = true
	_set_screen(S.SETTINGS)


func _settings_back() -> void:
	_sfx("button")
	if settings_return == S.PLAYING:
		_show_game()
	else:
		_show_menu()


func _toggle_swap() -> void:
	_sfx("button")
	layout_swapped = not layout_swapped
	_save_settings()
	_layout_bottom()
	queue_redraw()


func _layout_bottom() -> void:
	var narrow_x := 504.0 if layout_swapped else 20.0
	var wide_x := 20.0 if layout_swapped else 236.0
	ability_button.position = Vector2(20, 858)
	ability_button.size = Vector2(684, 68)
	die_pos = Vector2(narrow_x + 100, 986)
	roll_result_label.position = Vector2(narrow_x, 1038)
	roll_result_label.size = Vector2(200, 34)
	inv_btn.position = Vector2(narrow_x, 1082)
	inv_btn.size = Vector2(200, 74)
	settings_ingame_btn.position = Vector2(narrow_x, 1164)
	settings_ingame_btn.size = Vector2(200, 72)
	roll_button.position = Vector2(wide_x, 940)
	roll_button.size = Vector2(468, 108)
	log_panel.position = Vector2(wide_x, 1058)
	log_panel.size = Vector2(468, 178)


func _show_game() -> void:
	_set_screen(S.PLAYING)


func _start_tutorial(steps: Array) -> void:
	tut_steps = steps
	tut_index = 0
	for c in tut_dots_holder.get_children():
		c.queue_free()
	var n := steps.size()
	var total := n * 14 + (n - 1) * 8
	var sx := (440.0 - total) / 2.0
	for i in n:
		var dot := ColorRect.new()
		dot.position = Vector2(sx + i * 22, 0)
		dot.size = Vector2(14, 14)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tut_dots_holder.add_child(dot)
	_render_tut_step()
	tutorial_ui.visible = true
	tutorial_ui.get_parent().move_child(tutorial_ui, -1)
	queue_redraw()


func _render_tut_step() -> void:
	var step: Dictionary = tut_steps[tut_index]
	var dots := tut_dots_holder.get_children()
	for i in dots.size():
		dots[i].color = C_GOLD if i == tut_index else Color8(74, 64, 58)
	for c in tut_icon_holder.get_children():
		c.queue_free()
	var icons: Array = step["i"]
	var total_w := 0.0
	for iname in icons:
		var cols: int = SPRITES[iname][0].length()
		total_w += int(64.0 / cols) * cols + 12
	total_w -= 12
	var sx := (440.0 - total_w) / 2.0
	for iname in icons:
		var cols: int = SPRITES[iname][0].length()
		var rows: int = SPRITES[iname].size()
		var px := int(64.0 / cols)
		var tr := TextureRect.new()
		tr.texture = _sprite_texture(iname, px)
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.position = Vector2(sx, (100.0 - px * rows) / 2.0)
		tut_icon_holder.add_child(tr)
		sx += px * cols + 12
	tut_title.text = t(step["t"])
	tut_body.text = t(step["b"])
	tut_skip_btn.text = t("ui_skip")
	tut_skip_btn.visible = tut_index < tut_steps.size() - 1
	tut_next_btn.text = t("ui_next") if tut_index < tut_steps.size() - 1 else t("ui_play")


func _tut_next() -> void:
	_sfx("button")
	tut_index += 1
	if tut_index >= tut_steps.size():
		tutorial_ui.visible = false
		queue_redraw()
	else:
		_render_tut_step()


func _tut_skip() -> void:
	_sfx("button")
	tutorial_ui.visible = false
	queue_redraw()


# =====================================================================
#  XP / leveling
# =====================================================================
func _xp_needed() -> int:
	return 4 + hero_level * 2


func _gain_xp(n: int) -> void:
	if n <= 0:
		return
	hero_xp += n
	while hero_xp >= _xp_needed():
		hero_xp -= _xp_needed()
		hero_level += 1
		player.max_hp += 2
		player.hp += 2
		_sfx("win")
		add_log(t("log_levelup") % hero_level)
	update_hud()


# =====================================================================
#  Merchant / shop
# =====================================================================
func _item_by_id(id: String) -> Dictionary:
	for it in SHOP_ITEMS:
		if it["id"] == id:
			return it
	return {}


func _make_quest(tier: int) -> Dictionary:
	# tier 0 = easier/smaller stakes, 1 = harder/bigger stakes
	var span := 4 + tier + randi() % 2               # tier0: 4-5, tier1: 5-6 floors
	var target := randi_range(14, 20) if tier == 0 else randi_range(28, 42)
	var reward := {"gold": 0, "xp": 0}
	match randi() % 3:
		0:
			reward["gold"] = randi_range(18, 28) + tier * 10
		1:
			reward["xp"] = randi_range(3, 5) + tier * 2
		2:
			reward["gold"] = randi_range(10, 16) + tier * 6
			reward["xp"] = randi_range(2, 3)
	var penalty := {}
	if randi() % 2 == 0:
		penalty["gold"] = randi_range(6, 12) + tier * 4
	else:
		penalty["hp"] = randi_range(2, 3) + tier
	return {
		"kind": "gold",
		"deadline": level + span,
		"start_gold": int(player.gold),
		"target": target,
		"reward": reward,
		"penalty": penalty,
	}


func _quest_desc(q: Dictionary) -> String:
	return t("quest_gold") % int(q["target"])


func _quest_reward_text(q: Dictionary) -> String:
	var r: Dictionary = q["reward"]
	var g: int = int(r["gold"])
	var x: int = int(r["xp"])
	if g > 0 and x > 0:
		return t("quest_rew_gx") % [g, x]
	if x > 0:
		return t("quest_rew_x") % x
	return t("quest_rew_g") % g


func _quest_penalty_text(q: Dictionary) -> String:
	var p: Dictionary = q.get("penalty", {})
	if p.has("hp"):
		return t("quest_pen_h") % int(p["hp"])
	if p.has("gold"):
		return t("quest_pen_g") % int(p["gold"])
	return ""


func _open_shop() -> void:
	var ids: Array = []
	for it in SHOP_ITEMS:
		ids.append(it["id"])
	ids.shuffle()
	shop_offer = ids.slice(0, 3)
	shop_bought = {}
	shop_quest_pick = -1
	shop_quests = [_make_quest(0), _make_quest(1)]
	add_log(t("log_shop"))
	_render_shop()
	shop_ui.visible = true
	shop_ui.get_parent().move_child(shop_ui, -1)
	if not shop_tut_seen:
		shop_tut_seen = true
		_save_settings()
		_start_tutorial(TUT_SHOP)
	queue_redraw()


func _render_shop() -> void:
	shop_gold_label.text = "%d GP" % int(player.gold)
	shop_buy_hdr.text = t("shop_hdr_buy")
	shop_quest_hdr.text = t("shop_hdr_quest")
	shop_continue_btn.text = t("ui_continue")
	for i in 3:
		var it := _item_by_id(shop_offer[i])
		var row: Dictionary = shop_item_rows[i]
		row["icon"].texture = _sprite_texture(it["icon"], 8)
		row["name"].text = t(it["t"])
		row["desc"].text = t(it["b"])
		var pbtn: Button = row["price"]
		if shop_bought.get(it["id"], false):
			pbtn.text = t("shop_owned")
			pbtn.disabled = true
		else:
			pbtn.text = "%d GP" % int(it["cost"])
			pbtn.disabled = int(player.gold) < int(it["cost"])
	for i in 2:
		var q: Dictionary = shop_quests[i]
		var card: Dictionary = shop_quest_cards[i]
		var picked := shop_quest_pick == i
		card["title"].text = t("ui_quest") + (" *" if picked else "")
		card["body"].text = "%s\n%s\n\n%s\n%s" % [
			_quest_desc(q),
			t("quest_deadline") % int(q["deadline"]),
			_quest_reward_text(q),
			_quest_penalty_text(q),
		]
		card["root"].disabled = false
		_style_button(card["root"], "primary" if picked else "secondary")


func _buy_item(idx: int) -> void:
	var it := _item_by_id(shop_offer[idx])
	if shop_bought.get(it["id"], false) or int(player.gold) < int(it["cost"]):
		return
	_sfx("coin")
	player.gold = int(player.gold) - int(it["cost"])
	shop_bought[it["id"]] = true
	match it["id"]:
		"potion":
			player.hp = mini(int(player.max_hp), int(player.hp) + 5)
		"elixir":
			player.hp = int(player.max_hp)
		"maxhp":
			player.max_hp = int(player.max_hp) + 2
			player.hp = int(player.hp) + 2
		"tome":
			_gain_xp(3)
	add_log(t("log_bought") % t(it["t"]))
	update_hud()
	_render_shop()


func _pick_quest(idx: int) -> void:
	_sfx("button")
	# just highlight; nothing is committed until Continue is pressed
	shop_quest_pick = -1 if shop_quest_pick == idx else idx
	_render_shop()


func _check_quest_progress() -> void:
	if active_quest.is_empty():
		return
	var q := active_quest
	var done := (int(player.gold) - int(q["start_gold"])) >= int(q["target"])
	if done:
		var r: Dictionary = q["reward"]
		if int(r["gold"]) > 0:
			player.gold = int(player.gold) + int(r["gold"])
		if int(r["xp"]) > 0:
			_gain_xp(int(r["xp"]))
		active_quest = {}
		add_log(t("log_quest_done") % _quest_reward_text(q))
		update_hud()
	elif level >= int(q["deadline"]):
		var p: Dictionary = q.get("penalty", {})
		if p.has("gold"):
			player.gold = maxi(0, int(player.gold) - int(p["gold"]))
		if p.has("hp"):
			player.hp = maxi(1, int(player.hp) - int(p["hp"]))
		active_quest = {}
		add_log(t("quest_penalized") % _quest_penalty_text(q))
		update_hud()


func _close_shop() -> void:
	_sfx("button")
	if shop_quest_pick >= 0:
		active_quest = shop_quests[shop_quest_pick].duplicate(true)
		add_log(t("log_quest_take") % _quest_desc(active_quest))
	shop_ui.visible = false
	queue_redraw()


func _show_inventory() -> void:
	_sfx("button")
	inv_hero_sprite.texture = _sprite_texture(hero_class, 8)
	inv_hero_name.text = t("cls_%s_name" % hero_class)
	inv_hero_stats.text = ("Lv %d · " % hero_level) + (t("hud_level") % level) + ("\nHP %d/%d · " % [player.hp, player.max_hp]) + (t("inv_xp") % [hero_xp, _xp_needed()])
	inv_items_label.text = t("inv_no_items")
	if active_quest.is_empty():
		inv_quest_label.text = t("inv_no_quest")
	else:
		inv_quest_label.text = "%s\n%s\n%s\n%s" % [
			_quest_desc(active_quest),
			t("quest_deadline") % int(active_quest["deadline"]),
			_quest_reward_text(active_quest),
			_quest_penalty_text(active_quest),
		]
	_set_screen(S.INVENTORY)


# =====================================================================
#  Localization + settings
# =====================================================================
func t(key: String) -> String:
	var arr = STRINGS.get(key, null)
	if arr == null:
		return key
	var i := LANGS.find(locale)
	if i < 0:
		i = 0
	return arr[i]


func _set_language(l: String) -> void:
	_sfx("button")
	locale = l
	_save_settings()
	_apply_language()
	queue_redraw()


func _apply_language() -> void:
	play_btn.text = t("ui_play")
	settings_btn.text = t("ui_settings")
	slots_title.text = t("ui_choose_slot")
	class_title.text = t("ui_choose_class")
	settings_title.text = t("ui_settings")
	lang_title.text = t("ui_language")
	roll_button.text = t("ui_roll")
	settings_ingame_btn.text = t("ui_settings")
	swap_btn.text = t("ui_swap")
	howto_btn.text = t("ui_howto")
	save_exit_btn.text = t("ui_save_exit")
	death_title.text = t("ui_you_died")
	death_restart_btn.text = t("ui_restart")
	death_hint.text = t("death_hint")
	inv_btn.text = t("ui_bag")
	inv_title.text = t("ui_inventory")
	inv_items_title.text = t("ui_items")
	inv_quest_title.text = t("ui_quest")
	var classes := ["knight", "mage", "ranger"]
	for i in 3:
		class_name_labels[i].text = t("cls_%s_name" % classes[i])
		class_desc_labels[i].text = t("cls_%s_desc" % classes[i])
	_update_audio_buttons()
	_refresh_slots()
	if state == S.PLAYING:
		update_hud()
		_update_ability_ui()


func _load_settings() -> void:
	var c := ConfigFile.new()
	if c.load("user://settings.cfg") == OK:
		locale = c.get_value("general", "locale", "en")
		music_on = c.get_value("general", "music", true)
		sfx_on = c.get_value("general", "sfx", true)
		layout_swapped = c.get_value("general", "swapped", false)
		tutorial_seen = c.get_value("general", "tutorial_seen", false)
		shop_tut_seen = c.get_value("general", "shop_tut_seen", false)


func _save_settings() -> void:
	var c := ConfigFile.new()
	c.set_value("general", "locale", locale)
	c.set_value("general", "music", music_on)
	c.set_value("general", "sfx", sfx_on)
	c.set_value("general", "swapped", layout_swapped)
	c.set_value("general", "tutorial_seen", tutorial_seen)
	c.set_value("general", "shop_tut_seen", shop_tut_seen)
	c.save("user://settings.cfg")


func _toggle_music() -> void:
	music_on = not music_on
	_sfx("button")
	_save_settings()
	_play_music()
	_update_audio_buttons()


func _toggle_sfx() -> void:
	sfx_on = not sfx_on
	_sfx("button")
	_save_settings()
	_update_audio_buttons()


func _update_audio_buttons() -> void:
	if music_btn:
		music_btn.text = t("ui_music") + ": " + ("On" if music_on else "Off")
	if sfx_btn:
		sfx_btn.text = t("ui_sound") + ": " + ("On" if sfx_on else "Off")


# =====================================================================
#  Audio — procedurally generated 8-bit SFX + chill music loop
# =====================================================================
const SR := 22050

func _osc(freq: float, t: float, wave: String) -> float:
	var phase := freq * t
	match wave:
		"square":
			return 1.0 if fmod(phase, 1.0) < 0.5 else -1.0
		"tri":
			var p := fmod(phase, 1.0)
			return 4.0 * absf(p - 0.5) - 1.0
		"saw":
			return 2.0 * fmod(phase, 1.0) - 1.0
		"sine":
			return sin(phase * TAU)
		"noise":
			return randf() * 2.0 - 1.0
	return 0.0


func _note(freq: float, dur: float, wave: String, vol: float) -> PackedFloat32Array:
	var n := int(dur * SR)
	var out := PackedFloat32Array()
	out.resize(n)
	var atk := maxi(1, int(0.008 * SR))
	var rel := maxi(1, int(0.05 * SR))
	for i in n:
		var t := float(i) / SR
		var env := 1.0
		if i < atk:
			env = float(i) / atk
		elif i > n - rel:
			env = float(n - i) / rel
		out[i] = _osc(freq, t, wave) * vol * env
	return out


func _seq(notes: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for nt in notes:
		out.append_array(_note(nt[0], nt[1], nt[2], nt[3]))
	return out


func _make_wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _build_audio() -> void:
	music_player = AudioStreamPlayer.new()
	add_child(music_player)
	for i in 5:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

	sfx_bank["coin"] = _make_wav(_seq([[880, 0.05, "square", 0.3], [1320, 0.09, "square", 0.28]]))
	sfx_bank["chest"] = _make_wav(_seq([[660, 0.06, "square", 0.28], [880, 0.06, "square", 0.28], [1174, 0.12, "square", 0.26]]))
	sfx_bank["heart"] = _make_wav(_seq([[523, 0.08, "tri", 0.32], [784, 0.13, "tri", 0.28]]))
	sfx_bank["trap"] = _make_wav(_seq([[300, 0.06, "square", 0.28], [200, 0.08, "square", 0.26], [140, 0.13, "saw", 0.24]]))
	sfx_bank["hit"] = _make_wav(_seq([[130, 0.05, "noise", 0.35], [220, 0.05, "square", 0.3], [150, 0.1, "saw", 0.26]]))
	sfx_bank["step"] = _make_wav(_seq([[180, 0.03, "tri", 0.16]]))
	sfx_bank["roll"] = _make_wav(_seq([[500, 0.03, "square", 0.2], [720, 0.03, "square", 0.2]]))
	sfx_bank["button"] = _make_wav(_seq([[900, 0.03, "square", 0.22]]))
	sfx_bank["win"] = _make_wav(_seq([[523, 0.09, "square", 0.28], [659, 0.09, "square", 0.28], [784, 0.09, "square", 0.28], [1047, 0.18, "square", 0.3]]))
	sfx_bank["death"] = _make_wav(_seq([[392, 0.12, "saw", 0.3], [294, 0.12, "saw", 0.28], [196, 0.24, "saw", 0.28]]))

	music_player.stream = _build_music()
	_play_music()
	_update_audio_buttons()


func _build_music() -> AudioStreamWAV:
	var prog := [
		[220.0, 261.63, 329.63],   # Am
		[174.61, 220.0, 261.63],   # F
		[261.63, 329.63, 392.0],   # C
		[196.0, 246.94, 293.66]]   # G
	var note_dur := 0.28
	var order := [0, 1, 2, 1, 0, 1, 2, 1]
	var lead := PackedFloat32Array()
	var bass := PackedFloat32Array()
	for chord in prog:
		for idx in order:
			lead.append_array(_note(chord[idx] * 2.0, note_dur, "tri", 0.13))
		bass.append_array(_note(chord[0] * 0.5, note_dur * order.size(), "square", 0.05))
	var n := mini(lead.size(), bass.size())
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		out[i] = clampf(lead[i] + bass[i], -1.0, 1.0)
	return _make_wav(out, true)


func _sfx(sname: String) -> void:
	if not sfx_on:
		return
	var s = sfx_bank.get(sname, null)
	if s == null:
		return
	var p: AudioStreamPlayer = sfx_players[sfx_idx]
	sfx_idx = (sfx_idx + 1) % sfx_players.size()
	p.stream = s
	p.play()


func _play_music() -> void:
	if music_player == null:
		return
	if music_on and music_player.stream:
		if not music_player.playing:
			music_player.play()
	else:
		music_player.stop()


func _on_slot_pressed(i: int) -> void:
	_sfx("button")
	current_slot = i
	var data = _load_slot(i)
	if data is Dictionary and data.has("walls"):
		_begin_run(data)      # resume existing run (class stored inside)
		_show_game()
	else:
		_show_class()         # new game → pick a class first


func _choose_class(c: String) -> void:
	_sfx("button")
	hero_class = c
	_begin_run(null)
	_show_game()
	tutorial_seen = true
	_start_tutorial(TUT_GENERAL)   # show the intro on every new hero (Skip is there)


func _class_hp(c: String) -> int:
	match c:
		"mage": return 6
		"ranger": return 8
		_: return 10


func _on_ability() -> void:
	if state != S.PLAYING or spinning or game_over:
		return
	_sfx("button")
	match hero_class:
		"mage":
			if mage_casts <= 0 or not mage_turn_cast:
				return
			casting = not casting
			drilling = false
			_update_ability_ui()
			queue_redraw()
		"ranger":
			if not (wall_pass_available and _adjacent_to_wall()):
				return
			drilling = not drilling
			casting = false
			_update_ability_ui()
			queue_redraw()


func _update_ability_ui() -> void:
	ability_button.icon = ability_icon_tex.get(hero_class, null)
	match hero_class:
		"knight":
			ability_button.visible = true
			ability_button.disabled = false
			ability_button.text = t("ab_shield_ready") if knight_shield else t("ab_shield_used")
		"mage":
			ability_button.visible = true
			ability_button.disabled = mage_casts <= 0 or not mage_turn_cast
			ability_button.text = (t("ab_magic") % mage_casts) + (t("ab_target") if casting else "")
		"ranger":
			ability_button.visible = true
			ability_button.disabled = not (wall_pass_available and _adjacent_to_wall())
			if not wall_pass_available:
				ability_button.text = t("ab_wall_used")
			elif drilling:
				ability_button.text = t("ab_wall_target")
			else:
				ability_button.text = t("ab_wall")
		_:
			ability_button.visible = false


func _adjacent_to_wall() -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			if is_wall(player.pos + Vector2i(dx, dy)):
				return true
	return false


func _try_cast(cell: Vector2i) -> void:
	if mage_casts <= 0 or not mage_turn_cast:
		return
	var e = entity_at(cell)
	if e == null or e.type != "enemy":
		return
	var d := maxi(absi(cell.x - player.pos.x), absi(cell.y - player.pos.y))
	if d > 4:
		return
	e.alive = false
	mage_casts -= 1
	mage_turn_cast = false
	casting = false
	_sfx("hit")
	add_log(t("log_magic"))
	_update_ability_ui()
	queue_redraw()


func _try_drill(cell: Vector2i) -> void:
	if not wall_pass_available or not is_wall(cell):
		return
	var dx := absi(cell.x - player.pos.x)
	var dy := absi(cell.y - player.pos.y)
	if maxi(dx, dy) != 1:
		return   # must be an adjacent wall
	walls.erase(cell)          # permanent hole
	wall_pass_available = false
	drilling = false
	_sfx("trap")
	add_log(t("log_drill"))
	if awaiting_move:
		_compute_options()
	_update_ability_ui()
	queue_redraw()


func _exit_to_menu() -> void:
	_sfx("button")
	if current_slot >= 0 and not player.is_empty() and not game_over:
		_save_slot(current_slot, _serialize_state())
	_show_menu()


# =====================================================================
#  Local save slots (user://)
# =====================================================================
func _slot_path(i: int) -> String:
	return "user://slot_%d.save" % i


func _save_slot(i: int, data: Dictionary) -> void:
	var f := FileAccess.open(_slot_path(i), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()


func _load_slot(i: int):
	var p := _slot_path(i)
	if not FileAccess.file_exists(p):
		return null
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	return JSON.parse_string(txt)


func _delete_slot(i: int) -> void:
	_sfx("button")
	var fname := "slot_%d.save" % i
	var d := DirAccess.open("user://")
	if d and d.file_exists(fname):
		d.remove(fname)
	if current_slot == i:
		current_slot = -1
	_refresh_slots()


func _refresh_slots() -> void:
	for i in 3:
		var d = _load_slot(i)
		var filled := d is Dictionary
		slot_sprites[i].visible = filled
		slot_names[i].visible = filled
		slot_metas[i].visible = filled
		slot_hpbgs[i].visible = filled
		slot_hpfills[i].visible = filled
		del_buttons[i].visible = filled
		slot_newlabels[i].visible = not filled
		if filled:
			var cls: String = d.get("class", "knight")
			slot_sprites[i].texture = _sprite_texture(cls, 8)
			slot_names[i].text = "%s %d · %s" % [t("ui_slot"), i + 1, t("cls_%s_name" % cls)]
			slot_metas[i].text = (t("hud_level") % int(d.get("level", 1))) + " · %d GP" % int(d.get("gold", 0))
			var mhp: int = maxi(1, int(d.get("max_hp", 10)))
			var frac := clampf(float(int(d.get("hp", 10))) / mhp, 0.0, 1.0)
			slot_hpfills[i].size = Vector2(250.0 * frac, 18)
		else:
			slot_newlabels[i].text = t("ui_new_game")
		del_buttons[i].text = "x"


func _begin_run(data) -> void:
	if data is Dictionary and data.has("walls"):
		_restore_state(data)            # resume the exact saved level + path
		return
	if data == null:
		var mh := _class_hp(hero_class)
		player = {"pos": Vector2i(0, 0), "hp": mh, "max_hp": mh, "atk": 3, "gold": 0}
		level = 1
		hero_level = 1
		hero_xp = 0
		active_quest = {}
		next_shop_floor = randi_range(6, 8)
	else:
		hero_class = data.get("class", hero_class)
		player = {
			"pos": Vector2i(0, 0),
			"hp": int(data.get("hp", 10)),
			"max_hp": int(data.get("max_hp", 10)),
			"atk": 3,
			"gold": int(data.get("gold", 0))}
		level = int(data.get("level", 1))
		hero_xp = int(data.get("hero_xp", 0))
		active_quest = data.get("quest", {})
		next_shop_floor = int(data.get("next_shop", level + randi_range(2, 4)))
	new_level()


func _to_vec(a) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))


func _serialize_state() -> Dictionary:
	var w := []
	for c in walls:
		w.append([c.x, c.y])
	var ents := []
	for e in entities:
		ents.append({"t": e.type, "s": e.sprite, "x": e.pos.x, "y": e.pos.y, "a": e.alive})
	var pth := []
	for c in path:
		pth.append([c.x, c.y])
	return {
		"level": level,
		"hero_level": hero_level,
		"hero_xp": hero_xp,
		"next_shop": next_shop_floor,
		"quest": active_quest,
		"class": hero_class,
		"shield": knight_shield,
		"wallpass": wall_pass_available,
		"casts": mage_casts,
		"gold": player.gold, "hp": player.hp, "max_hp": player.max_hp,
		"entrance": [entrance_cell.x, entrance_cell.y],
		"exit": [exit_cell.x, exit_cell.y],
		"ppos": [player.pos.x, player.pos.y],
		"walls": w,
		"entities": ents,
		"path": pth,
	}


func _restore_state(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	hero_level = int(data.get("hero_level", 1))
	hero_xp = int(data.get("hero_xp", 0))
	active_quest = data.get("quest", {})
	next_shop_floor = int(data.get("next_shop", level + randi_range(2, 4)))
	hero_class = data.get("class", "knight")
	entrance_cell = _to_vec(data.get("entrance", [0, 0]))
	exit_cell = _to_vec(data.get("exit", [COLS - 1, ROWS - 1]))
	player = {
		"pos": _to_vec(data.get("ppos", [0, 0])),
		"hp": int(data.get("hp", 10)),
		"max_hp": int(data.get("max_hp", 10)),
		"atk": 3,
		"gold": int(data.get("gold", 0))}

	walls = {}
	for a in data.get("walls", []):
		walls[_to_vec(a)] = true

	entities = []
	for e in data.get("entities", []):
		var ep := Vector2i(int(e.get("x", 0)), int(e.get("y", 0)))
		entities.append({
			"type": e.get("t", "coin"), "sprite": e.get("s", "coin"),
			"pos": ep, "prev": ep,
			"alive": bool(e.get("a", true)), "hp": 1, "atk": 0, "gold": 0})

	path = []
	for a in data.get("path", []):
		path.append(_to_vec(a))
	if path.is_empty():
		path = [player.pos]

	current_n = 0
	diagonal = false
	options = []
	option_paths = {}
	awaiting_move = false
	spinning = false
	game_over = false
	pending_advance = false
	if death_ui:
		death_ui.visible = false
	knight_shield = bool(data.get("shield", hero_class == "knight"))
	wall_pass_available = bool(data.get("wallpass", hero_class == "ranger"))
	drilling = false
	mage_casts = int(data.get("casts", 3))
	mage_turn_cast = false
	casting = false
	show_die = false
	die_angle = 0.0
	log_lines = []

	add_log(t("log_resume") % level)
	roll_result_label.text = ""
	_update_main_button()
	_update_ability_ui()
	update_hud()
	queue_redraw()


# =====================================================================
#  Level setup
# =====================================================================
func new_level() -> void:
	# entrance and exit in two different quarters of the board
	var q_start := randi() % 4
	var q_exit := (q_start + 1 + randi() % 3) % 4
	entrance_cell = _rand_in_quarter(q_start)
	exit_cell = _rand_in_quarter(q_exit)

	# keep hero stats (hp / max_hp / gold) — only reset per-level state
	player["pos"] = entrance_cell
	current_n = 0
	diagonal = false
	options = []
	option_paths = {}
	awaiting_move = false
	path = [entrance_cell]
	entities = []
	spinning = false
	game_over = false
	pending_advance = false
	if death_ui:
		death_ui.visible = false
	knight_shield = (hero_class == "knight")
	wall_pass_available = (hero_class == "ranger")
	drilling = false
	mage_casts = 3
	mage_turn_cast = false
	casting = false
	show_die = false
	die_angle = 0.0
	log_lines = []

	_generate_level()

	add_log(t("log_new_level") % level)
	roll_result_label.text = ""
	_update_main_button()
	_update_ability_ui()
	update_hud()
	queue_redraw()


# Random cell inside quarter q (0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right).
func _rand_in_quarter(q: int) -> Vector2i:
	var hx := COLS / 2
	var hy := ROWS / 2
	var x := (q % 2) * hx + randi() % hx
	var y := (q / 2) * hy + randi() % hy
	return Vector2i(x, y)


func _place(type: String, x: int, y: int, extra: Dictionary = {}) -> void:
	var sprite := type
	if type == "enemy":
		sprite = "enemy" if randi() % 2 == 0 else "skull"
	elif type == "trap":
		sprite = "trap" if randi() % 2 == 0 else "beartrap"
	var e := {"type": type, "sprite": sprite, "pos": Vector2i(x, y), "prev": Vector2i(x, y), "alive": true, "hp": 1, "atk": 0, "gold": 0}
	for k in extra:
		e[k] = extra[k]
	entities.append(e)


func is_wall(cell: Vector2i) -> bool:
	return walls.has(cell)


# Generate random walls, then scatter entities on free reachable cells.
# Regenerates until the exit is reachable from the entrance.
func _generate_level() -> void:
	var entrance := entrance_cell
	var target := int(COLS * ROWS * 0.11)
	for attempt in 40:
		walls = {}
		var placed := 0
		var tries := 0
		while placed < target and tries < 300:
			tries += 1
			var wall := _make_wall()
			if wall.size() < 4:
				continue
			for c in wall:
				walls[c] = true
			placed += wall.size()
		var reach := _reachable(entrance)
		if reach.has(exit_cell) and _all_free_reachable(reach):
			_populate_entities(reach)
			return
	# fallback: no walls at all
	walls = {}
	_populate_entities(_reachable(entrance))


# Every non-wall cell must be reachable — rejects sealed-off pockets/rooms.
func _all_free_reachable(reach: Dictionary) -> bool:
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if not is_wall(c) and not reach.has(c):
				return false
	return true


# Lay one wall: a 1-cell-thick line with at most one 90° turn (a straight line
# or an L). Never forms a 2x2 block, stays >=2 cells from the border and from
# any other wall — so corridors are always >=2 wide (diagonal moves possible)
# and no wall can enclose a sealed room.
func _make_wall() -> Array:
	var cells := {}
	var ordered: Array = []
	var cur := Vector2i(2 + randi() % (COLS - 4), 2 + randi() % (ROWS - 4))
	if not _wall_cell_ok(cur, cells):
		return []
	cells[cur] = true
	ordered.append(cur)

	var dir := _rand_axis_dir()
	var total_len := 4 + randi() % 6     # 4..9 cells
	var bends_left := 1                  # at most one turn (no rings / notches)
	var until_bend := 2 + randi() % 3
	while ordered.size() < total_len:
		var nxt: Vector2i = cur + dir
		if not _wall_cell_ok(nxt, cells):
			break
		cells[nxt] = true
		ordered.append(nxt)
		cur = nxt
		until_bend -= 1
		if bends_left > 0 and until_bend <= 0 and randi() % 100 < 35:
			dir = _perp(dir)
			bends_left -= 1
	return ordered


func _wall_cell_ok(cell: Vector2i, cells: Dictionary) -> bool:
	# keep walls at least 2 cells away from the terrain border
	if cell.x < 2 or cell.y < 2 or cell.x >= COLS - 2 or cell.y >= ROWS - 2:
		return false
	if cell == entrance_cell or cell == exit_cell:
		return false
	if walls.has(cell) or cells.has(cell):
		return false
	# at least 2 empty cells between this wall and any OTHER wall
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if walls.has(cell + Vector2i(dx, dy)):
				return false
	# keep 1-thick: adding this cell must not complete any 2x2 block
	if _would_make_square(cell, cells):
		return false
	return true


func _would_make_square(cell: Vector2i, cells: Dictionary) -> bool:
	for corner in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
		var full := true
		for off in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			var cc: Vector2i = cell + corner + off
			if cc != cell and not cells.has(cc):
				full = false
				break
		if full:
			return true
	return false


func _rand_axis_dir() -> Vector2i:
	match randi() % 4:
		0: return Vector2i(1, 0)
		1: return Vector2i(-1, 0)
		2: return Vector2i(0, 1)
		_: return Vector2i(0, -1)


func _perp(d: Vector2i) -> Vector2i:
	if d.x != 0:
		return Vector2i(0, 1) if randi() % 2 == 0 else Vector2i(0, -1)
	return Vector2i(1, 0) if randi() % 2 == 0 else Vector2i(-1, 0)


# Cells reachable by straight slides (1..6 in any of 8 directions), transitively.
func _reachable(start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var stack: Array = [start]
	var dirs: Array = ORTHO_DIRS + DIAG_DIRS
	while not stack.is_empty():
		var cur: Vector2i = stack.pop_back()
		for d in dirs:
			var p: Vector2i = cur
			for step in 6:
				var np: Vector2i = p + d
				if np.x < 0 or np.y < 0 or np.x >= COLS or np.y >= ROWS:
					break
				if is_wall(np):
					break
				p = np
				if not seen.has(p):
					seen[p] = true
					stack.append(p)
	return seen


func _populate_entities(reach: Dictionary) -> void:
	entities = []
	var free: Array = []
	for c in reach:
		if c == entrance_cell or c == exit_cell:
			continue
		free.append(c)
	free.shuffle()

	var idx := 0
	var counts := {
		"enemy": 1 + randi() % 10,   # 1..10
		"trap": 1 + randi() % 10,    # 1..10
		"coin": 1 + randi() % 10,    # 1..10
		"heart": 1 + randi() % 10,   # 1..10
		"chest": randi() % 6,        # 0..5
	}
	for etype in counts:
		for i in counts[etype]:
			if idx >= free.size():
				return
			_place(etype, free[idx].x, free[idx].y)
			idx += 1


func entity_at(cell: Vector2i):
	for e in entities:
		if e.alive and e.pos == cell:
			return e
	return null


# =====================================================================
#  Roll the die
# =====================================================================
func _on_roll() -> void:
	if game_over or spinning or awaiting_move:
		return
	spinning = true
	roll_button.disabled = true
	options = []
	show_die = true
	_sfx("roll")
	queue_redraw()

	var total := 10 + randi() % 5
	for i in total:
		die_value = 1 + randi() % 6
		die_angle += 0.55
		roll_result_label.text = ""
		queue_redraw()
		await get_tree().create_timer(0.03 + i * 0.0028).timeout

	current_n = 1 + randi() % 6
	diagonal = (current_n % 2) == 1
	die_value = current_n
	die_angle = 0.0
	spinning = false
	if hero_class == "mage":
		mage_turn_cast = true   # one cast available this turn
	_compute_options()

	var mode_txt := t("mode_diag") if diagonal else t("mode_straight")
	if options.is_empty():
		add_log(t("log_no_move"))
		roll_button.disabled = false
	else:
		awaiting_move = true
		add_log(t("log_rolled") % [current_n, mode_txt])
	_update_ability_ui()
	_update_roll_label()
	queue_redraw()


func _compute_options() -> void:
	options = []
	option_paths = {}
	_explore(player.pos, current_n, Vector2i.ZERO, [], true)
	if hero_class == "ranger":
		_explore(player.pos, current_n + 1, Vector2i.ZERO, [], true)  # +1 step option
	for cell in option_paths:
		options.append(cell)


# Explore every route of `steps` cells: slide straight until a wall, then turn
# (never back the way we came) and spend the remaining steps. Each final cell
# becomes a clickable option with its full bent path stored.
func _explore(pos: Vector2i, steps: int, came_dir: Vector2i, acc: Array, is_root: bool) -> void:
	var dirs := DIAG_DIRS if diagonal else ORTHO_DIRS
	var advanced := false
	for d in dirs:
		if d == -came_dir:
			continue  # can't turn back the way you came
		var k := _max_steps(pos, d, steps)
		if k < 1:
			continue
		advanced = true
		var p := pos
		var seg: Array = []
		for i in k:
			p = p + d
			seg.append(p)
		var rem := steps - k
		if rem <= 0:
			_add_option(p, acc + seg)        # used all steps
		else:
			_explore(p, rem, d, acc + seg, false)  # hit wall, turn and continue
	if not advanced and not is_root:
		_add_option(pos, acc)  # stuck against a wall, stop here


func _add_option(cell: Vector2i, full_path: Array) -> void:
	if not option_paths.has(cell):
		option_paths[cell] = full_path


func _max_steps(from: Vector2i, d: Vector2i, n: int) -> int:
	var k := 0
	var p := from
	for i in n:
		var np: Vector2i = p + d
		if np.x < 0 or np.y < 0 or np.x >= COLS or np.y >= ROWS:
			break
		if is_wall(np):
			break  # walls block movement
		p = np
		k += 1
	return k


# =====================================================================
#  Input — pick a destination option
# =====================================================================
func _unhandled_input(event: InputEvent) -> void:
	if state != S.PLAYING or game_over or spinning:
		return
	var sp = null
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		sp = event.position
	elif event is InputEventScreenTouch and event.pressed:
		sp = event.position
	if sp == null:
		return

	var world: Vector2 = get_global_transform_with_canvas().affine_inverse() * sp
	if world.y < GRID_TOP:
		return
	var cell := Vector2i(int(world.x / TILE), int((world.y - GRID_TOP) / TILE))
	if cell.x < 0 or cell.y < 0 or cell.x >= COLS or cell.y >= ROWS:
		return

	if casting:
		_try_cast(cell)
		return
	if drilling:
		_try_drill(cell)
		return
	if awaiting_move and cell in options:
		_do_move(cell)


func _do_move(target: Vector2i) -> void:
	var full_path: Array = option_paths.get(target, [])
	options = []
	option_paths = {}
	awaiting_move = false

	var start_pos: Vector2i = player.pos
	var hp_before: int = player.hp
	var gold_before: int = player.gold

	for cell in full_path:
		player.pos = cell
		path.append(cell)
		_resolve_tile(cell)
		if game_over:
			break

	update_hud()

	casting = false
	drilling = false
	_update_ability_ui()
	_sfx("step")

	if pending_advance:
		pending_advance = false
		level += 1
		_sfx("win")
		new_level()             # HP carries over to the next floor
		add_log(t("log_win") % level)
		_gain_xp(1)             # a little XP for clearing a floor
		_check_quest_progress()
		if level >= next_shop_floor:
			next_shop_floor = level + randi_range(6, 8)
			_open_shop()
		return

	if not game_over:
		var steps := full_path.size()
		var first_dir: Vector2i = full_path[0] - start_pos if steps > 0 else Vector2i.ZERO
		var msg := t("log_move") % [_dir_word(first_dir), steps]
		var gd: int = player.gold - gold_before
		var hd: int = player.hp - hp_before
		if gd != 0:
			msg += t("log_gp") % gd
		if hd != 0:
			msg += t("log_hp") % hd
		add_log(msg)
		_enemy_phase()          # enemies move immediately after your move
		if not game_over:
			roll_button.disabled = false
	_update_roll_label()
	queue_redraw()


func _dir_word(d: Vector2i) -> String:
	var h := ""
	var v := ""
	if d.x > 0:
		h = "r"
	elif d.x < 0:
		h = "l"
	if d.y > 0:
		v = "d"
	elif d.y < 0:
		v = "u"
	if h != "" and v != "":
		return t("dir_" + v + h)          # dr, dl, ur, ul
	elif h != "":
		return t("dir_right") if h == "r" else t("dir_left")
	elif v != "":
		return t("dir_down") if v == "d" else t("dir_up")
	return "?"


func _update_roll_label() -> void:
	roll_result_label.text = t("mode_diag") if diagonal else t("mode_straight")


func _update_main_button() -> void:
	roll_button.text = t("ui_roll")
	roll_button.disabled = awaiting_move or spinning or game_over


# Move every enemy one step right after the player moves.
# Returns true if the player died and the floor restarted.
func _enemy_phase() -> void:
	for e in entities:
		if game_over:
			break
		if e.alive and e.type == "enemy":
			_step_enemy(e)
	update_hud()


func _step_enemy(e: Dictionary) -> void:
	e.prev = e.pos    # remember where it moved from (for the last-move indicator)
	var dist := maxi(absi(e.pos.x - player.pos.x), absi(e.pos.y - player.pos.y))
	var chase := dist <= 7
	var candidates: Array = []
	for d in ORTHO_DIRS + DIAG_DIRS:
		var tgt: Vector2i = e.pos + d
		if tgt.x < 0 or tgt.y < 0 or tgt.x >= COLS or tgt.y >= ROWS:
			continue
		if is_wall(tgt):
			continue
		if tgt == player.pos:
			if chase:
				candidates.append(tgt)   # intercept: may step onto you to attack
			continue
		var occ = entity_at(tgt)
		if occ != null and occ.type == "enemy":
			continue
		candidates.append(tgt)
	if candidates.is_empty():
		return
	if chase:
		# move to the valid cell closest to the player (may be your own cell = attack)
		var best: Vector2i = candidates[0]
		var bestd := maxi(absi(best.x - player.pos.x), absi(best.y - player.pos.y))
		for c in candidates:
			var cd := maxi(absi(c.x - player.pos.x), absi(c.y - player.pos.y))
			if cd < bestd:
				bestd = cd
				best = c
		if best == player.pos:
			_enemy_attack(e)
		else:
			e.pos = best
	else:
		e.pos = candidates[randi() % candidates.size()]


func _enemy_attack(e: Dictionary) -> void:
	e.alive = false    # the enemy clashes onto you and dies
	_sfx("hit")
	if hero_class == "knight" and knight_shield:
		knight_shield = false      # shield absorbs the hit first
		add_log(t("log_shield"))
		_update_ability_ui()
	else:
		player.hp -= 1 + randi() % 6
		_check_death()




func _resolve_tile(cell: Vector2i) -> void:
	if cell == exit_cell:
		_win()
		return
	var ent = entity_at(cell)
	if ent == null:
		return
	ent.alive = false
	match ent.type:
		"enemy":
			_sfx("hit")
			if hero_class == "knight" and knight_shield:
				knight_shield = false      # free kill, no damage
				add_log(t("log_shield"))
			else:
				player.hp -= 1 + randi() % 6
				_check_death()
		"trap":
			_sfx("trap")
			player.gold = maxi(0, player.gold - (1 + randi() % 6))
		"coin":
			_sfx("coin")
			player.gold += 1
		"chest":
			_sfx("chest")
			player.gold += 1 + randi() % 6
		"heart":
			_sfx("heart")
			player.hp = mini(player.max_hp, player.hp + 1 + randi() % 6)


# =====================================================================
#  Death / win
# =====================================================================
func _check_death() -> void:
	if player.hp <= 0:
		player.hp = 0
		game_over = true
		awaiting_move = false
		_show_death()


func _show_death() -> void:
	death_summary.text = t("death_reached") % [level, player.gold]
	roll_button.disabled = true
	death_ui.visible = true
	_sfx("death")
	queue_redraw()


func _restart_run() -> void:
	_sfx("button")
	death_ui.visible = false
	var mh := _class_hp(hero_class)
	player = {"pos": Vector2i(0, 0), "hp": mh, "max_hp": mh, "atk": 3, "gold": 0}
	level = 1
	hero_level = 1
	hero_xp = 0
	active_quest = {}
	next_shop_floor = randi_range(6, 8)
	new_level()


func _win() -> void:
	game_over = true
	awaiting_move = false
	pending_advance = true


# =====================================================================
#  HUD / log
# =====================================================================
func update_hud() -> void:
	hp_label.text = "%d/%d" % [player.hp, player.max_hp]
	gold_label.text = "%d" % player.gold
	level_label.text = "%d" % hero_level
	floor_label.text = t("hud_level") % level


func add_log(msg: String) -> void:
	log_label.text = msg  # only the most recent event


# =====================================================================
#  Rendering
# =====================================================================
func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c.x * TILE + TILE / 2.0, GRID_TOP + c.y * TILE + TILE / 2.0)


func _draw_sprite(sprite_name: String, ctr: Vector2) -> void:
	var map: Array = SPRITES[sprite_name]
	var rows := map.size()
	var cols: int = map[0].length()
	var px := TILE / float(cols)
	var ox := ctr.x - cols * px / 2.0
	var oy := ctr.y - rows * px / 2.0
	for y in rows:
		var row: String = map[y]
		for x in cols:
			var ch := row[x]
			if SPRITE_PAL.has(ch):
				draw_rect(Rect2(ox + x * px, oy + y * px, px + 0.7, px + 0.7), SPRITE_PAL[ch], true)


func _draw_background() -> void:
	var w := COLS * TILE
	var h := 1280
	draw_rect(Rect2(0, 0, w, h), C_BG, true)
	var bw := 48
	var bh := 24
	var rows := int(h / bh) + 1
	var cols := int(w / bw) + 2
	for row in range(rows):
		var y := row * bh
		var off := (bw / 2) if (row % 2 == 1) else 0
		draw_line(Vector2(0, y), Vector2(w, y), C_BG_LO, 1.0)
		for col in range(-1, cols):
			var x := col * bw + off
			draw_line(Vector2(x, y), Vector2(x, y + bh), C_BG_LO, 1.0)
			draw_line(Vector2(x + 1, y + 1), Vector2(x + bw - 1, y + 1), C_BG_HI, 1.0)


func _draw() -> void:
	_draw_background()
	if state != S.PLAYING:
		return
	var grid_bottom := GRID_TOP + ROWS * TILE

	# parchment play field
	draw_rect(Rect2(0, GRID_TOP, COLS * TILE, ROWS * TILE), C_PAPER, true)

	# grid lines
	for i in range(COLS + 1):
		draw_line(Vector2(i * TILE, GRID_TOP), Vector2(i * TILE, grid_bottom), C_LINE, 1.0)
	for j in range(ROWS + 1):
		draw_line(Vector2(0, GRID_TOP + j * TILE), Vector2(COLS * TILE, GRID_TOP + j * TILE), C_LINE, 1.0)

	# gold trim around the field
	draw_rect(Rect2(0, GRID_TOP - 3, COLS * TILE, 3), C_GOLD, true)
	draw_rect(Rect2(0, grid_bottom, COLS * TILE, 3), C_GOLD, true)

	# walls — stone blocks, beveled only on the outer edge of each wall mass
	for w in walls:
		var wx: float = w.x * TILE
		var wy: float = GRID_TOP + w.y * TILE
		draw_rect(Rect2(wx, wy, TILE, TILE), C_WALL, true)
		if not is_wall(w + Vector2i(0, -1)):
			draw_rect(Rect2(wx, wy, TILE, 3), C_WALL_HI, true)
		if not is_wall(w + Vector2i(-1, 0)):
			draw_rect(Rect2(wx, wy, 3, TILE), C_WALL_HI, true)
		if not is_wall(w + Vector2i(0, 1)):
			draw_rect(Rect2(wx, wy + TILE - 3, TILE, 3), C_WALL_LO, true)
		if not is_wall(w + Vector2i(1, 0)):
			draw_rect(Rect2(wx + TILE - 3, wy, 3, TILE), C_WALL_LO, true)

	# entrance (stairs) + exit (door)
	_draw_sprite("stairs", cell_center(entrance_cell))
	_draw_sprite("door", cell_center(exit_cell))

	# travelled pencil line
	if path.size() >= 2:
		var pts := PackedVector2Array()
		for c in path:
			pts.append(cell_center(c))
		draw_polyline(pts, C_INK, 3.0, true)

	# entities (pixel sprites)
	for e in entities:
		var ctr := cell_center(e.pos)
		if not e.alive:
			_draw_dead(ctr)
		else:
			if e.type == "enemy" and e.get("prev", e.pos) != e.pos:
				var from := cell_center(e.prev)
				draw_line(from, ctr, Color(0.70, 0.30, 0.30, 0.55), 2.5)
				draw_circle(from, TILE * 0.13, Color(0.70, 0.30, 0.30, 0.40))
			_draw_sprite(e.sprite, ctr)

	# movement options (after a roll) — show the full route incl. turns
	var pc_start := cell_center(player.pos)
	var opt_r := TILE * 0.40
	for opt in options:
		var op_path: Array = option_paths.get(opt, [])
		var pts2 := PackedVector2Array()
		pts2.append(pc_start)
		for c in op_path:
			pts2.append(cell_center(c))
		if pts2.size() >= 2:
			draw_polyline(pts2, Color(0.29, 0.49, 0.35, 0.5), 2.0, true)
		var oc := cell_center(opt)
		draw_circle(oc, opt_r, Color(0.29, 0.49, 0.35, 0.30))
		draw_arc(oc, opt_r, 0, TAU, 22, C_GREEN, 2.0)

	# mage targeting — highlight enemies within range 4
	if casting:
		for e in entities:
			if e.alive and e.type == "enemy":
				var dd := maxi(absi(e.pos.x - player.pos.x), absi(e.pos.y - player.pos.y))
				if dd <= 4:
					draw_arc(cell_center(e.pos), TILE * 0.5, 0, TAU, 20, Color(0.85, 0.2, 0.28), 3.0)

	# ranger drilling — highlight adjacent walls that can be breached
	if drilling:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var wc: Vector2i = player.pos + Vector2i(dx, dy)
				if is_wall(wc):
					draw_rect(Rect2(wc.x * TILE, GRID_TOP + wc.y * TILE, TILE, TILE), Color(0.95, 0.6, 0.15), false, 3.0)

	# player (class-specific hero sprite)
	_draw_sprite(hero_class, cell_center(player.pos))

	# rolling die (bottom controls area)
	if show_die:
		_draw_die(die_pos, 78.0, die_value, die_angle)


func _draw_die(center: Vector2, s: float, value: int, angle: float) -> void:
	draw_set_transform(center, angle, Vector2.ONE)
	var h := s * 0.5
	var bw := s * 0.10
	# bone face
	draw_rect(Rect2(-h, -h, s, s), Color8(240, 231, 208), true)
	# pixel bevel (light top-left, dark bottom-right)
	draw_rect(Rect2(-h, -h, s, bw), Color8(255, 250, 234), true)
	draw_rect(Rect2(-h, -h, bw, s), Color8(255, 250, 234), true)
	draw_rect(Rect2(-h, h - bw, s, bw), Color8(196, 182, 148), true)
	draw_rect(Rect2(h - bw, -h, bw, s), Color8(196, 182, 148), true)
	# gold border (matches the buttons)
	draw_rect(Rect2(-h, -h, s, s), Color8(201, 162, 39), false, 4.0)
	# square pips (pixel style)
	var d := s * 0.27
	var pr := s * 0.10
	var layouts := {
		1: [Vector2(0, 0)],
		2: [Vector2(-d, -d), Vector2(d, d)],
		3: [Vector2(-d, -d), Vector2(0, 0), Vector2(d, d)],
		4: [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, d), Vector2(d, d)],
		5: [Vector2(-d, -d), Vector2(d, -d), Vector2(0, 0), Vector2(-d, d), Vector2(d, d)],
		6: [Vector2(-d, -d), Vector2(d, -d), Vector2(-d, 0), Vector2(d, 0), Vector2(-d, d), Vector2(d, d)],
	}
	for p in layouts.get(value, layouts[1]):
		draw_rect(Rect2(p.x - pr, p.y - pr, pr * 2.0, pr * 2.0), C_INK, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_dead(ctr: Vector2) -> void:
	var d := TILE * 0.22
	draw_line(ctr + Vector2(-d, -d), ctr + Vector2(d, d), C_GRAY, 2.5)
	draw_line(ctr + Vector2(d, -d), ctr + Vector2(-d, d), C_GRAY, 2.5)
