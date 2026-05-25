enum AppLanguage { en, he }

class AppStrings {
  final AppLanguage lang;
  const AppStrings(this.lang);

  bool get isHebrew => lang == AppLanguage.he;

  // ── Home screen ─────────────────────────────────────────────────────────────
  String get appSubtitle =>
      isHebrew ? 'משחק קוביות ל-2 עד 6 שחקנים' : 'A dice game for 2–6 players';
  String get orStartNew =>
      isHebrew ? 'או התחל משחק חדש' : 'OR START A NEW GAME';
  String get numPlayers => isHebrew ? 'מספר שחקנים' : 'Number of Players';
  String get playerNames => isHebrew ? 'שמות שחקנים' : 'Player Names';
  String get gameMode => isHebrew ? 'מצב משחק' : 'Game Mode';
  String get modeLocal => isHebrew ? 'מקומי — העבר ושחק' : 'Local — Pass & Play';
  String get modeComputer => isHebrew ? 'נגד מחשב' : 'vs Computer';
  String get modeOnline => isHebrew ? 'רשת — מרובה שחקנים' : 'Online Multiplayer';
  String get comingSoon => isHebrew ? 'בקרוב' : 'Coming Soon';
  String get startGame => isHebrew ? 'התחל משחק' : 'Start Game';
  String get savedGame => isHebrew ? 'משחק שמור' : 'Saved Game';
  String get continueGame => isHebrew ? 'המשך משחק' : 'Continue Game';
  String get vsSeparator => isHebrew ? ' נגד ' : ' vs ';
  String playerLabel(int n) => isHebrew ? 'שחקן $n' : 'Player $n';
  String playerDefault(int n) => isHebrew ? 'שחקן $n' : 'Player $n';
  String savedTurnInfo(String name, int score) => isHebrew
      ? 'תור של $name  •  $score נקודות'
      : "$name's turn  •  $score pts";

  // ── Action buttons ───────────────────────────────────────────────────────────
  String get roll => isHebrew ? 'הטל 🎲' : 'Roll 🎲';
  String get bank => isHebrew ? 'עצור ✓' : 'Bank ✓';
  String get confirmSelection => isHebrew ? 'אשר בחירה ▶' : 'Confirm Selection ▶';
  String get selectOneDie =>
      isHebrew ? 'בחר לפחות קובייה אחת' : 'Select at least one die';
  String get steal => isHebrew ? 'גנוב ⚡' : 'Steal ⚡';
  String get skip => isHebrew ? 'דלג ▶' : 'Skip ▶';
  String get newGame => isHebrew ? 'משחק חדש' : 'New Game';
  String get continueBtn => isHebrew ? 'המשך ▶' : 'Continue ▶';

  // ── Turn indicator ───────────────────────────────────────────────────────────
  String get turnScore => isHebrew ? 'ניקוד התור: ' : 'Turn score: ';
  String get availableToSteal => isHebrew ? 'זמין לגניבה: ' : 'Available to steal: ';
  String hotDice(String name) =>
      isHebrew ? '🔥  $name — קוביות חמות!  +200' : '🔥  $name — HOT DICE!  +200';
  String farkle(String name) =>
      isHebrew ? '💥  $name — איקס!' : '💥  $name — FARKLE!';
  String ceilingBust(String name) =>
      isHebrew ? '💥  $name — פוצצת! מעל 10,000' : '💥  $name — BUST! Over 10,000';
  String winsReveal(String name) =>
      isHebrew ? '🏆  $name מנצח!' : '🏆  $name wins!';
  String winsBanner(String name) => isHebrew ? '$name מנצח!' : '$name wins!';
  String winsScore(int score) =>
      isHebrew ? '${_fmt(score)} נקודות' : '${_fmt(score)} pts';
  String get rollAgainOrBank =>
      isHebrew ? 'הטל שוב או עצור' : 'Roll again or bank your score';
  String get scoreNotRound =>
      isHebrew ? 'ניקוד לא עגול — חייב להמשיך' : 'Score not round — must keep rolling';
  String get hotDiceForced =>
      isHebrew ? 'כל 5 נקודו! הטל שוב (+200 בונוס)' : 'All 5 scored! Roll all dice again (+200 bonus)';
  String rollAvailable(int pts) => isHebrew
      ? 'הטלה: +$pts זמין — בחר קוביות, אשר'
      : 'Roll: +$pts available — select dice, then confirm';
  String get selectDice =>
      isHebrew ? 'בחר קוביות להפריש, אשר' : 'Select dice to set aside, then confirm';
  String diceRemaining(int n) =>
      isHebrew ? '$n קוביות נותרו — גנוב או דלג?' : '$n dice remaining — steal or skip?';

  // ── Dice board ───────────────────────────────────────────────────────────────
  String get diceToSteal => isHebrew ? 'קוביות לגניבה' : 'Dice available to steal';
  String get locked => isHebrew ? 'נעול' : 'LOCKED';
  String inheritedFrom(String name) =>
      isHebrew ? 'עובר מ-$name' : 'Inherited from $name';
  String yourDice(int n) =>
      isHebrew ? 'הקוביות שלך ($n נותרו)' : 'Your dice ($n remaining)';

  // ── Help modal ───────────────────────────────────────────────────────────────
  String get helpTitle => isHebrew ? 'ספר החוקים' : 'Rulebook';
  String get rulebookContent => isHebrew ? _heRulebook : _enRulebook;

  static String _fmt(int score) {
    if (score >= 1000) {
      return '${score ~/ 1000},${(score % 1000).toString().padLeft(3, '0')}';
    }
    return '$score';
  }
}

// ── Rulebook texts (word-for-word) ─────────────────────────────────────────────

const String _heRulebook = '''
# 🎲 ספר החוקים הרשמי: משחק "קוביות'"

## סעיף 1: הציוד והגדרות יסוד
* **מה צריך?** 5 קוביות משחק סטנדרטיות (6 פאות, מספרים 1 עד 6), דף ועט לרישום הניקוד.
* **מספר שחקנים:** 2 שחקנים ומעלה.

## סעיף 2: המטרה הסופית
* המטרה של כל שחקן היא להיות הראשון שמגיע ל-**10,000 נקודות בדיוק**. ברגע ששחקן מגיע למספר זה, המשחק נגמר מיד והוא המנצח (אין סיבוב נקמה, המשחק נעצר באותו הרגע).

## סעיף 3: לוח הניקוד (שילובי הקוביות)
כדי שקובייה או שילוב קוביות ייחשבו כנקודות, עליהם להופיע באותה ההטלה בדיוק. אלו הצירופים המעניקים נקודות:
* **3א. קובייה בודדת של 1:** שווה 100 נקודות.
* **3ב. קובייה בודדת של 5:** שווה 50 נקודות.
* **3ג. שלישיית 1:** שלוש קוביות המציגות `1` בהטלה אחת שוות 1,000 נקודות.
* **3ד. שלישייה זהה אחרת:** שלוש קוביות המציגות `2`, `3`, `4` או `6` שוות את ערך הקובייה כפול 100 (למשל: `[4][4][4]` שווה 400 נקודות).
* **3ד.א. חוק הקובייה המשלימה לשלישייה:** אם בהטלת המשך (או באותה הטלה שבה יצאה שלישייה) יוצאת קובייה נוספת הזהה לשלישייה שהופרשה קודם לכן, כל קובייה נוספת כזו שווה **100 נקודות** נוספות (ולא את ערך הקובייה המקורי שלה). *(לדוגמה: אם שמרת שלישיית 5, ובהטלה הבאה יצא `5`, הקובייה הזו שווה עוד 100 נקודות ולא 50).*
* **3ה. רצף מלא:** חמש קוביות עוקבות המציגות `[1][2][3][4][5]` או `[2][3][4][5][6]` שוות 1,500 נקודות.
*(הערה: חוקי רצף קטן, זוג כפול וחמישיית "קוד 5" מבוטלים לחלוטין).*

## סעיף 4: מהלך התור של השחקן והדילמה
* **4א. הטלה ראשונית:** השחקן לוקח את כל 5 הקוביות ומטיל אותן.
* **4ב. חובת הפרשה:** השחקן חייב להפריש הצידה לפחות קובייה אחת או שילוב אחד ששווים נקודות בכל הטלה.
* **4ג. חוק הסכום העגול והדילמה:**
  * **אפשרות א' (לעצור):** השחקן רשאי לבחור לעצור ולרשום את הנקודות בדף **רק אם** סכום הנקודות הזמני שצבר באותו התור הוא סכום "עגול" (כפולה של 100, למשל: 400, 500, 1,100).
  * **אפשרות ב' (להמשיך לזרוק):** השחקן רשאי לבחור להמשיך להטיל את הקוביות שנותרו "קרות" על השולחן על מנת לצבור סכום נקודות גדול יותר. במידה ולשחקן יש סכום קוביות זמני שאינו עגול (לדוגמה, הוא הפריש קוביית `5` ששווה 50 נקודות), האפשרות הזו הופכת ל**חובה**: הוא חייב להמשיך לזרוק את הקוביות שנותרו עד שיצטבר לו סכום עגול, ואינו יכול לעצור לפני כן.
* **4ד. חוק הקוביות החמות (חובת הטלה מחדש ובונוס "דרך צלחה"):** אם שחקן הצליח להשתמש בכל 5 הקוביות שלו לצבירת נקודות במהלך התור, הוא **מחויב** לקחת את כל 5 הקוביות מחדש ולהטיל אותן. בתמורה לסיכון הכפוי, הוא מקבל **בונוס של 200 נקודות "מתנה"** המתווספות לניקוד הזמני שלו.

## סעיף 5: סכנות, קנסות ומדרגות ניקוד
* **5א. הטלת "איקס":** אם שחקן מטיל קוביות ואף אחת מהן לא יוצרת שילוב ששווה נקודות – התור שלו מסתיים מיד. הוא מקבל "איקס" (X) ומפסיד את כל הנקודות שצבר בתור הספציפי הזה. ה"איקסים" נשמרים ומצטברים לאורך המשחק עבור אותה המדרגה, עד אשר מדרגת הניקוד הנוכחית של השחקן "נשרפת".
* **5ב. חוק שלושת האיקסים:** שחקן שצבר 3 איקסים ברציפות (3 תורים שנשרפו) – מדרגת הניקוד הנוכחית שלו נשרפת, והוא יורד אוטומטית ל**מדרגת הניקוד שהייתה לו בתור שבו רשם נקודות לאחרונה**.
* **5ג. חוק "הגניבה המבוטחת":** כששחקן מסיים את התור שלו מרצון ומשאיר קוביות "שאריות" על השולחן, השחקן הבא בתור יכול לבחור "לגנוב" את התור: הוא מתחיל עם נקודות הבסיס שהשאיר הקודם ומטיל רק את הקוביות שנותרו.
  * **הסיכון:** אם השחקן הגונב מקבל הטלת "איקס" – התור שלו מסתיים, הנקודות של התור נמחקות, והוא מקבל **איקס (X) למדרגה הנוכחית שלו** (אין הורדת נקודות מהלוח הכללי).
* **5ד. חוק "המדרגה החופפת":** אם שחקן מסיים את התור שלו ועוצר **בדיוק** באותה מדרגת ניקוד (סכום נקודות כללי) שבה עומד כרגע שחקן אחר – הוא "עולה עליו" ומדיח אותו מדרגה אחת מטה (למדרגתו הקודמת של השחקן המודח). מעבר של שחקן דרך מדרגה של שחקן אחר במהלך התור מבלי לעצור בה, אינו פוגע בשחקן האחר.
* **5ה. חוק "המדרגה הראשונה" (סף כניסה):** כדי להתחיל לצבור נקודות על הלוח ולפתוח את המשחק, שחקן חייב להגיע בתור בודד לניקוד של **400 נקודות ומעלה** ולשמור אותו. עד שהוא לא משיג 400 נקודות לפחות בתור אחד, הוא לא יכול לרשום נקודות וחייב להמשיך להטיל.
* **5ה.א. חסינות לאחר כניסה:** אם שחקן כבר נכנס למשחק (עבר את סף ה-400), אך בהמשך ספג 3 איקסים או שחקן אחר "עלה עליו" והוא הודח חזרה ל-0 נקודות – הוא נחשב כמי ש"כבר במשחק". בתור הבא שלו הוא רשאי לעצור ולשמור גם ניקוד הנמוך מ-400 (כל עוד הוא סכום עגול).
* **5ו. חוק תקרת ה-10,000:** אם שחקן מבצע הטלה והסכום המצטבר של אותה הטלה (ביחד עם הניקוד שכבר יש לו בדף ובאותו התור) עובר את ה-10,000 – **ההטלה נחשבת כאיקס**. השחקן מאבד את כל הנקודות של אותו התור, והתור עובר הלאה.

---

## 📜 נספח א': מדריך פרשנות ומקרי קצה (FAQ)

### 🔍 חלק 1: לולאות כפויות וסכומים עגולים
> **שאלה:** מה קורה אם הגעתי למצב של "קוביות חמות" (כל 5 הקוביות צברו ניקוד), אבל סך הנקודות שלי כרגע הוא לא עגול (למשל 650)?

**ההסבר והחוק:**
במצב כזה, חוק הקוביות החמות (סעיף 4ד) גובר ומאלץ אותך להטיל מחדש את כל 5 הקוביות. אתה מקבל מיד 200 נקודות בונוס (מה שמביא אותך ל-850). מאחר ו-850 הוא עדיין סכום לא עגול, **אסור לך לעצור**. אתה מחויב להטיל את הקוביות שוב ושוב עד שתצליח "לעגל" את הסכום, או עד שתקבל "איקס" ותפסיד הכל.

### 💥 חלק 2: קוביות חמות בהטלת איקס
> **שאלה:** מה קורה אם הגעתי לקוביות חמות, קיבלתי את בונוס ה-200 נקודות, אבל בהטלה הכפויה של 5 הקוביות קיבלתי "איקס"?

**ההסבר והחוק:**
אם חטפת "איקס" בהטלה החמה, הבונוס של ה-200 נקודות **לא נשמר** והאיקס שורף לחלוטין את התור כולו. הכל מתאפס ואתה חוזר למדרגה איתה התחלת את התור.

### ♟️ חלק 3: חוק המדרגה החופפת והורדת שחקנים ברגע העצירה
> **שאלה:** במהלך התור שלי הגעתי לצירוף קוביות שהביא אותי בדיוק לניקוד הכללי של שחקן אחר, אך החלטתי להמשיך לזרוק כדי להשיג ניקוד גבוה יותר. האם הוא מודח?

**ההסבר והחוק:**
**לא, הוא לא מודח.** חוק המדרגה החופפת (סעיף 5ד) מופעל **אך ורק ברגע העצירה הסופי של התור**.
* אם הגעת לניקוד שלו (למשל 2,000) והחלטת לעצור ולרשום את הניקוד בדף – אתה עולה עליו והוא מודח מדרגה אחת מטה.
* אם החלטת לקחת סיכון, הטלת שוב ועברת את ה-2,000 (למשל הגעת ל-2,300) – השחקן השני בטוח לחלוטין במקומו, מכיוון שלא עצרת על המדרגה שלו.

### 📉 חלק 4: חוק שלושת האיקסים והירידה במדרגות
> **שאלה:** לאן בדיוק אני יורד אם חטפתי 3 איקסים ברציפות?

**ההסבר והחוק:**
הירידה היא לא לפי סכום קבוע, אלא חזרה לנקודת הציון האחרונה שבה **רשמת נקודות בהצלחה**.
* *דוגמה:* אם היית על 1,100 נקודות, ובתור הבא עשית סיבוב מוצלח ועצרת על 1,500 נקודות – זו המדרגה החדשה שלך. אם בשלושת התורים הבאים קיבלת איקסים, אתה חוזר בדיוק ל-1,100 נקודות (התחנה הבטוחה האחרונה שלך).

### 💰 חלק 5: חוקיות והשלכות הגניבה המבוטחת
> **שאלה:** האם מותר לי לבצע "גניבה מבוטחת" על תור שנשרף, ומה קורה אם נכשלתי בגניבה?

**ההסבר והחוק:**
ניתן לבצע גניבה מבוטחת אך ורק אם השחקן ששיחק לפניך סיים תור חוקי (סכום עגול) ובחר לעצור מרצונו כשיש קוביות "שאריות" על השולחן. אם הוא חטף "איקס" – התור שלו נמחק לחלוטין ואתה מחויב להתחיל מאפס.
אם בחרת לגנוב וחטפת "איקס", **הניקוד הכללי שלך בדף לא נפגע**. התור שלך פשוט נגמר מייד, ואתה מסמן **איקס (X) אחד** על המדרגה הנוכחית שלך, דבר שמקרב אותך לסכנת שלושת האיקסים (סעיף 5ב).

### 🛑 חלק 6: מלכודת הקוביות החמות ותקרת ה-10,000
> **שאלה:** שחקן נמצא קרוב מאוד ל-10,000 נקודות והקוביות שלו התחממו. מתווסף לו בונוס כפוי של 200 נקודות, והוא מחויב להטיל מחדש את כל 5 הקוביות. מה קורה אם הבונוס או ההטלה הבאה מעבירים אותו את ה-10,000?

**ההסבר והחוק:**
חוק תקרת ה-10,000 וחוק הקוביות החמות מתנגשים כאן, והשחקן מחויב ללכת עד הסוף. אם הבונוס עצמו, או כל נקודה שיקבל בהטלה החמה החדשה (אפילו קוביית `5` בודדת), יעבירו את סך הניקוד שלו מעבר ל-10,000 בדיוק – **התור כולו נשרף ונחשב כאיקס!** השחקן חוזר למדרגה המקורית איתה התחיל את התור.
* *איך בכל זאת מנצחים במצב כזה?* הדרך היחידה של השחקן להינצל ולנצח היא אם בהטלה החמה הכפויה של 5 הקוביות הוא יקבל **"איקס טבעי"** (אפס נקודות בקוביות), ובכך לא יתווספו לו נקודות שיעברו את התקרה, והוא יישאר בדיוק על ה-10,000.

### 💥 חלק 7: אפקט הדומינו / "נחיתת חירום" (שילוב חוק 5ב ו-5ד)
> **שאלה:** שחקן א' יושב על מדרגת ניקוד מסוימת. שחקן ב', שהיה במדרגה גבוהה יותר, חטף את האיקס השלישי שלו ונאלץ לרדת למדרגתו הקודמת – שהיא בדיוק המדרגה שבה יושב כרגע שחקן א'. מה קורה?

**ההסבר והחוק:**
שחקן א' סופג "פגיעה משנית" אכזרית. ברגע ששחקן ב' נוחת במדרגה הקודמת שלו בגלל הקנס של שלושת האיקסים, הוא מפעיל אוטומטית את חוק המדרגה החופפת (סעיף 5ד). שחקן א' מודח מיד ומגורש מדרגה אחת מטה, אל התחנה הבטוחה הקודמת שלו (לדוגמה, אם שחקן ב' צנח חזרה ל-1,500 שבו ישב שחקן א', שחקן א' מגורש מיד למדרגתו הקודמת, למשל 1,000).
* *היגיון אסטרטגי:* לעולם אל תישאר "מתחת" לשחקן שנמצא בסכנת איקס שלישי, הוא עלול ליפול עליך ולגרור אותך איתו למטה!
''';

const String _enRulebook = '''
# 🎲 Official Rulebook: "Kubiyot" (Dice)

## Section 1: Equipment and Basic Definitions
* **Requirements:** 5 standard 6-sided dice, paper, and a pen for scoring.
* **Players:** 2 or more players.

## Section 2: Ultimate Goal
* The goal of each player is to be the first to reach **EXACTLY 10,000 points**. The moment a player hits this score, the game ends instantly, and they are declared the winner.

## Section 3: The Scoreboard (Dice Combinations)
Dice combinations must appear within the exact same roll to count:
* **3a. Single [1]:** Worth 100 points.
* **3b. Single [5]:** Worth 50 points.
* **3c. Three-of-a-kind [1]s:** Three dice showing `1` in a single roll are worth 1,000 points.
* **3d. Other Three-of-a-kind:** Three dice showing `2`, `3`, `4`, or `6` are worth the face value multiplied by 100 (e.g., `[4][4][4]` equals 400 points).
* **3d.a. Complementary Die Rule:** If a player rolls a die that matches a previously set-aside three-of-a-kind during subsequent rolls in the same turn, each matching die adds **100 points** (instead of its standard value). *(Example: If you kept a three-of-a-kind of 5, and in the next roll a `5` appears, that die is worth an additional 100 points, not 50).*
* **3e. Full Straight:** Five consecutive dice showing `[1][2][3][4][5]` or `[2][3][4][5][6]` are worth 1,500 points.
*(Note: Small straights, double pairs, and five-of-a-kind "code 5" rules are completely disabled).*

## Section 4: Player's Turn and the Dilemma
* **4a. Initial Roll:** The player rolls all 5 dice.
* **4b. Mandatory Setting Aside:** The player must set aside at least one scoring die or combination from each roll.
* **4c. The Rounding Rule and the Dilemma:**
  * **Option A (Bank):** A player may choose to end their turn and bank their points **ONLY IF** the temporary points gathered during that turn form a "round number" (a multiple of 100, e.g., 400, 500, 1,100).
  * **Option B (Continue Rolling):** A player can choose to keep rolling the remaining "cold" dice to accumulate more points. If their temporary turn score is not a round number (e.g., they set aside a `5` worth 50 points), this option becomes **mandatory**: they must continue rolling until the score becomes a round number.
* **4d. Hot Dice Rule (Forced Re-roll and "Passing Go" Bonus):** If a player successfully sets aside all 5 dice for points during a turn, they **MUST** pick up all 5 dice and roll again. In exchange for this forced risk, they receive a flat **bonus of 200 "gift" points** added to their temporary score.

## Section 5: Risks, Penalties, and Score Tiers
* **5a. Rolling an "X" (Bust):** If a roll yields 0 scoring dice, the turn ends instantly. The player gets an "X" and loses all points gathered in that specific turn. "X" marks accumulate on the current tier until it is burned.
* **5b. Three "X"s Rule:** A player who accumulates 3 consecutive "X"s burns their current score tier and automatically drops back to the **exact score tier they successfully banked last**.
* **5c. Secured Theft Rule:** When a player voluntarily banks their points and leaves leftover dice on the table, the next player can choose to "steal" the turn: they inherit the baseline points and roll only the remaining dice.
  * **The Risk:** If the stealing player rolls an "X", their turn ends, the turn points are wiped, and they receive an **"X" on their current score tier** (no points are deducted from their permanent board score).
* **5d. Overlapping Tier Rule:** If a player ends their turn and banks a score that lands **EXACTLY** on the current total score of another player, they "stomp" them. The stomped player is demoted one tier down (to their own previous score tier). Passing through a score during a turn without banking exactly on it does not trigger a demotion.
* **5e. First Tier Entry Rule:** To start tracking points on the board, a player must score at least **400 points or more** in a single turn. Until they do, they cannot bank any points.
* **5e.a. Entry Immunity:** If a player has already entered the game but gets knocked back to 0 points (via 3 Xs or being stomped), they retain their entry status. On their next turn, they can bank any legal round score under 400.
* **5f. The 10,000 Ceiling Rule:** Since the goal is exactly 10,000 points, if a roll causes the player's cumulative turn and board score to exceed 10,000, **the roll is deemed an "X"**. The entire turn score is wiped out, and the turn ends.

---

## 📜 Appendix A: Interpretation Guide and Edge Cases (FAQ)

### 🔍 Part 1: Forced Loops and Round Scores
> **Question:** What happens if I trigger "Hot Dice" but my temporary score is not a round number (e.g., 650)?

**Explanation and Rule:**
The Hot Dice rule (Section 4d) forces you to roll all 5 dice again. You immediately receive the 200-point bonus (bringing you to 850). Since 850 is still not a round number, **you cannot stop**. You are forced to roll until you manage to "round out" the score or roll an "X" and lose it all.

### 💥 Part 2: Hot Dice on an "X" Roll
> **Question:** What happens if I get Hot Dice, receive the 200 bonus, but roll an "X" on the forced 5-dice roll?

**Explanation and Rule:**
If you bust on the forced roll, the 200-point bonus **is not saved**, and the "X" wipes out the entire turn. You return to the score tier you started the turn with.

### ♟️ Part 3: Overlapping Tiers and Voluntarily Banking
> **Question:** During my turn, a roll puts my temporary score exactly on another player's total score, but I choose to keep rolling. Is that player demoted?

**Explanation and Rule:**
**No, they are not.** The Overlapping Tier Rule (Section 5d) is triggered **ONLY at the exact moment a score is officially banked**. If you bypass the number and keep rolling, the other player is perfectly safe.

### 📉 Part 4: The Three "X"s Demotion Mechanics
> **Question:** Where exactly do I drop down to if I get 3 consecutive "X"s?

**Explanation and Rule:**
You drop back to the last milestone where you **successfully banked points**. For example: if you were at 1,100, then successfully banked a 1,500 turn, 1,500 is your new tier. If you then get 3 "X"s in a row, you return to exactly 1,100.

### 💰 Part 5: Secured Theft Validity and Failures
> **Question:** Can I steal a broken turn, and what happens if I fail a theft?

**Explanation and Rule:**
You can only steal if the previous player ended a legal turn and voluntarily banked a round score. If they busted on an "X", the turn is dead, and you must start from 5 dice. If you attempt a theft and roll an "X", **your permanent score is safe**. Your turn simply ends, and you mark **one "X"** on your current tier.

### 🛑 Part 6: The 10,000 Hot Dice Trap
> **Question:** I am close to 10,000 points and my dice get hot. The forced +200 bonus or the next roll pushes me over 10,000. What happens?

**Explanation and Rule:**
The turn busts completely. The only way to win via a forced Hot Dice re-roll near the finish line is if you roll a **natural "X"** (0 points) on that 5-dice roll, which prevents any points from breaking the 10,000 ceiling, keeping you exactly at 10,000.

### 💥 Part 7: The Domino Effect / "Crash Landing"
> **Question:** Player A is sitting on a score tier. Player B, who was higher up, gets a 3rd "X" and drops back to their previous tier—which happens to be exactly where Player A is sitting. What happens?

**Explanation and Rule:**
Player A suffers unfair collateral damage. As Player B crash-lands onto Player A's tier, the Overlapping Tier Rule (Section 5d) triggers automatically. Player A is instantly demoted to their own previous score tier.
* *Strategic Advice:* Never stay directly underneath a player who has 2 "X"s; they might crash into you!
''';
