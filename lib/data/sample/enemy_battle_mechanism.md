# Enemy Battle Mechanism

Tài liệu này mô tả cơ chế trận đánh với enemy trong app học tiếng Anh kết hợp thu thập thú cưng. Mỗi stage là một trận chiến nhỏ. Người chơi trả lời câu hỏi để gây sát thương lên enemy, trừ máu enemy và hoàn thành stage.

---

## 1. Mục tiêu thiết kế

Cơ chế battle cần đạt 4 mục tiêu chính:

1. Biến việc trả lời câu hỏi thành hành động có cảm giác game hơn.
2. Giữ bản chất học tập: người chơi vẫn phải làm đủ số câu cần thiết.
3. Tạo nhịp tăng độ khó theo stage: minion → guardian → elite → boss.
4. Kết nối với hệ thống pet, combo, energy, skill và reward.

Luồng cơ bản:

```text
Start stage
→ Enemy appears
→ Show enemy HP / shield
→ Player answers questions
→ Correct answer deals damage
→ Wrong answer triggers penalty
→ Enemy defeated
→ Stage completed
→ Calculate stars and rewards
```

---

## 2. Cấu trúc enemy trong JSON

Mỗi stage có một object `enemy`.

Ví dụ:

```json
{
  "enemy": {
    "id": "enemy_01_01_pencil_gremlin",
    "name": "Pencil Gremlin",
    "theme": "School Supplies",
    "element": "Knowledge",
    "enemyType": "minion",
    "battleRole": "learning_enemy",
    "rank": "minion",
    "sizeClass": "small",
    "level": 11,
    "maxHp": 90,
    "hp": 90,
    "shield": 0,
    "attackPower": 0,
    "assetKey": "enemy_pencil_gremlin",
    "introText": "Pencil Gremlin appears while you learn new school supplies words.",
    "battleRules": {
      "basePlayerDamageTarget": 10,
      "hpFormula": "recommendedQuestionCount * basePlayerDamageTarget * difficultyHpMultiplier",
      "difficultyHpMultiplier": 0.9,
      "defeatCondition": "Reduce enemy HP to 0. If questions end and HP remains, use bonus questions when allowed.",
      "wrongAnswerPenalty": {
        "heartDamage": 0,
        "bossShieldGain": 0,
        "comboReset": true
      }
    },
    "skill": {
      "id": "light_counter",
      "name": "Light Counter",
      "description": "A wrong answer only resets the player's combo."
    },
    "tags": ["school_supplies", "knowledge", "minion", "easy"]
  }
}
```

---

## 3. Phân loại enemy theo độ khó stage

Enemy được phân loại dựa trên `difficulty` của stage.

| Stage difficulty | Enemy type | Vai trò | Cảm giác trong game |
|---|---|---|---|
| `easy` | `minion` | Quái nhỏ | Nhẹ nhàng, dùng cho học từ mới |
| `normal` | `guardian` | Quái canh giữ | Ôn tập cơ bản |
| `hard` | `elite` | Quái tinh anh | Ôn tập nâng cao, có shield nhẹ |
| `boss` | `topic_boss` | Boss chủ đề | Final review của topic ngắn/trung bình |
| `elite_boss` | `elite_topic_boss` | Boss lớn | Final review của topic dài hoặc mốc lớn |

Mapping trong config:

```json
{
  "enemyTypeByDifficulty": {
    "easy": "minion",
    "normal": "guardian",
    "hard": "elite",
    "boss": "topic_boss",
    "elite_boss": "elite_topic_boss"
  }
}
```

---

## 4. Công thức tính máu enemy

Máu enemy được tính dựa trên số câu hỏi được đề xuất cho stage.

```text
enemy.maxHp = roundUpToNearest10(
  recommendedQuestionCount × basePlayerDamageTarget × difficultyHpMultiplier
)
```

Trong đó:

```json
{
  "basePlayerDamageTarget": 10,
  "difficultyHpMultiplier": {
    "easy": 0.9,
    "normal": 1.0,
    "hard": 1.15,
    "boss": 1.3,
    "elite_boss": 1.5
  }
}
```

Ví dụ stage `hard` có 13 câu:

```text
13 × 10 × 1.15 = 149.5
roundUpToNearest10 = 150 HP
```

Ví dụ stage `elite_boss` có 34 câu:

```text
34 × 10 × 1.5 = 510 HP
```

---

## 5. Shield của enemy

Shield là lớp giáp chặn damage trước khi trừ vào HP.

```json
{
  "baseShieldByDifficulty": {
    "easy": 0,
    "normal": 0,
    "hard": 10,
    "boss": 25,
    "elite_boss": 40
  }
}
```

Cách hoạt động:

```text
Player deals damage
→ If enemy has shield, reduce shield first
→ Remaining damage reduces HP
```

Ví dụ:

```text
Enemy HP: 200
Enemy shield: 25
Player damage: 15

Result:
Shield: 10
HP: 200
```

Lần đánh tiếp theo:

```text
Enemy HP: 200
Enemy shield: 10
Player damage: 20

Result:
Shield: 0
HP: 190
```

---

## 6. Damage khi trả lời đúng

Mỗi câu trả lời đúng sẽ gây damage lên enemy.

Damage cơ bản có thể phụ thuộc vào loại câu hỏi:

| Question type | Damage đề xuất |
|---|---:|
| `imageChoice` | 8 |
| `wordMeaningMatch` | 10 |
| `listeningChoice` | 12 |
| `contextFillBlank` | 14 |
| `wordArrangement` | 14 |
| `typingSpelling` | 16 |
| `bossMixedChallenge` | 18 |
| `speedReview` | 10 |

Config đề xuất:

```json
{
  "questionDamage": {
    "imageChoice": 8,
    "wordMeaningMatch": 10,
    "listeningChoice": 12,
    "contextFillBlank": 14,
    "wordArrangement": 14,
    "typingSpelling": 16,
    "bossMixedChallenge": 18,
    "speedReview": 10
  }
}
```

---

## 7. Combo damage

Combo giúp người chơi gây nhiều damage hơn khi trả lời đúng liên tiếp.

```json
{
  "comboDamageBonus": [
    { "comboMin": 3, "damageMultiplier": 1.1 },
    { "comboMin": 5, "damageMultiplier": 1.2 },
    { "comboMin": 10, "damageMultiplier": 1.35 },
    { "comboMin": 15, "damageMultiplier": 1.5 }
  ]
}
```

Ví dụ:

```text
Base damage: 10
Combo: 5
Multiplier: 1.2
Final damage: 12
```

Khi trả lời sai:

```text
combo = 0
```

Trừ khi pet có skill bảo vệ combo.

---

## 8. Energy và ultimate skill

Mỗi câu trả lời đúng sẽ tăng energy cho pet/team. Khi energy đầy, người chơi có thể tung skill.

```json
{
  "energyRules": {
    "maxEnergy": 100,
    "correctAnswer": 10,
    "combo5Bonus": 5,
    "perfectAnswerBonus": 5,
    "wrongAnswer": 0
  }
}
```

Ví dụ:

```text
Correct answer: +10 energy
Correct answer at combo 5: +15 energy
Perfect timing answer: +15 energy
Wrong answer: +0 energy
```

Ultimate skill ví dụ:

```json
{
  "ultimateSkill": {
    "id": "wisdom_blast",
    "name": "Wisdom Blast",
    "energyCost": 100,
    "damage": 50,
    "effect": "Deal bonus damage to the enemy."
  }
}
```

---

## 9. Xử lý trả lời sai

Sai câu không nên phạt quá nặng vì đây là app học. Penalty tăng dần theo độ khó.

```json
{
  "wrongAnswerPenaltyByDifficulty": {
    "easy": {
      "heartDamage": 0,
      "bossShieldGain": 0,
      "comboReset": true
    },
    "normal": {
      "heartDamage": 1,
      "bossShieldGain": 0,
      "comboReset": true
    },
    "hard": {
      "heartDamage": 1,
      "bossShieldGain": 5,
      "comboReset": true
    },
    "boss": {
      "heartDamage": 1,
      "bossShieldGain": 10,
      "comboReset": true
    },
    "elite_boss": {
      "heartDamage": 1,
      "bossShieldGain": 15,
      "comboReset": true
    }
  }
}
```

Ý nghĩa:

| Difficulty | Sai câu sẽ xảy ra gì? |
|---|---|
| `easy` | Chỉ mất combo |
| `normal` | Mất 1 heart, reset combo |
| `hard` | Mất 1 heart, enemy được +5 shield, reset combo |
| `boss` | Mất 1 heart, enemy được +10 shield, reset combo |
| `elite_boss` | Mất 1 heart, enemy được +15 shield, reset combo |

---

## 10. Điều kiện thắng

Có 2 cách để thắng stage:

### Cách 1: Hạ enemy

```text
enemy.hp <= 0
→ victory
```

### Cách 2: Đủ điểm qua màn

Nếu hết câu mà enemy còn HP, có thể cho thắng nếu đạt `passingScorePercent`.

```text
accuracy >= passingScorePercent
→ victory by score
```

Đề xuất dùng cả 2 để app không quá khó:

```json
{
  "victoryRule": {
    "enemyDefeated": true,
    "allowVictoryByPassingScore": true,
    "useBonusQuestionsWhenEnemySurvives": true
  }
}
```

---

## 11. Bonus questions khi enemy còn máu

Nếu hết câu mà enemy chưa chết, có thể mở thêm câu bonus.

```json
{
  "bonusQuestionRule": {
    "enabled": true,
    "maxBonusQuestions": 3,
    "triggerWhenEnemyHpAbove": 0,
    "requiredAccuracyToEnterBonus": 70
  }
}
```

Flow:

```text
Questions ended
→ Enemy HP > 0
→ Accuracy >= 70%
→ Open up to 3 bonus questions
→ Correct answer deals final damage
```

Nếu sau bonus enemy vẫn còn HP:

```text
If accuracy >= passingScorePercent
→ Victory by passing score
Else
→ Stage failed
```

---

## 12. Overkill bonus khi enemy chết sớm

Nếu enemy bị hạ trước khi hết câu, không nên kết thúc stage ngay. Người chơi vẫn nên học đủ câu.

Đề xuất:

```text
Enemy defeated early
→ Remaining questions become Overkill Bonus
→ Correct answers give extra coin / food / shard chance
```

Config đề xuất:

```json
{
  "overkillBonus": {
    "enabled": true,
    "coinPerCorrectAnswer": 2,
    "foodPerCorrectAnswer": 3,
    "extraShardChancePerCorrectAnswer": 0.01,
    "maxExtraShardChance": 0.08
  }
}
```

Ví dụ:

```text
Enemy died at question 10/14
Remaining 4 questions become overkill bonus
Player answers 3/4 correctly
→ +6 coin
→ +9 food
→ +3% extra shard chance
```

---

## 13. Enemy skill theo độ khó

Enemy nên có skill đơn giản theo rank.

| Enemy type | Skill gợi ý | Tác dụng |
|---|---|---|
| `minion` | `Light Counter` | Sai câu chỉ reset combo |
| `guardian` | `Small Strike` | Sai câu mất 1 heart |
| `elite` | `Shield Up` | Sai câu enemy nhận shield |
| `topic_boss` | `Boss Guard` | Sai câu enemy nhận nhiều shield hơn |
| `elite_topic_boss` | `Final Barrier` | Có shield cao, sai câu tăng shield mạnh |

Ví dụ:

```json
{
  "skill": {
    "id": "shield_up",
    "name": "Shield Up",
    "description": "When the player answers incorrectly, this enemy gains extra shield."
  }
}
```

---

## 14. Tác động của pet lên battle

Pet không nên làm game mất cân bằng, nhưng nên có tác dụng để người chơi muốn sưu tập và nâng cấp.

| Rarity | Battle bonus đề xuất |
|---|---|
| Common | +3% damage hoặc +3% food |
| Rare | +6% damage, +5% combo bonus |
| Epic | +10% damage, có tỉ lệ bỏ qua shield |
| Legendary | +15% damage, tăng energy hoặc revive nhẹ |

Ví dụ:

```json
{
  "petBattleBonus": {
    "common": {
      "damageBonusPercent": 3
    },
    "rare": {
      "damageBonusPercent": 6,
      "comboBonusPercent": 5
    },
    "epic": {
      "damageBonusPercent": 10,
      "ignoreShieldChance": 0.08
    },
    "legendary": {
      "damageBonusPercent": 15,
      "ultimateChargeBonusPercent": 10,
      "reviveChance": 0.1
    }
  }
}
```

Lưu ý cân bằng:

```text
Pet mạnh giúp đánh boss nhanh hơn,
nhưng không nên khiến người chơi bỏ qua việc học.
```

---

## 15. Tính star sau trận

Số sao stage nên dựa trên accuracy, combo và số heart còn lại.

```json
{
  "stageStarRules": [
    {
      "stars": 1,
      "accuracyMin": 60
    },
    {
      "stars": 2,
      "accuracyMin": 75,
      "maxWrongAnswers": 3
    },
    {
      "stars": 3,
      "accuracyMin": 90,
      "maxWrongAnswers": 1
    }
  ]
}
```

Đề xuất:

| Stars | Điều kiện |
|---|---|
| 1 star | Đạt passing score |
| 2 stars | Accuracy >= 75%, sai không quá 3 câu |
| 3 stars | Accuracy >= 90%, sai không quá 1 câu |

---

## 16. Liên kết battle với reward

Battle result ảnh hưởng đến reward.

```text
Better accuracy
→ More stars
→ Higher reward multiplier
→ More coin / food / shard chance
```

Ví dụ:

```json
{
  "performanceRewardMultiplier": {
    "1star": 0.7,
    "2stars": 1.0,
    "3stars": 1.25
  }
}
```

Khi thắng boss hoặc elite boss:

```text
Boss defeated
→ Guaranteed shard chance
→ Higher evolution stone chance
→ Common egg / rare egg chance
```

---

## 17. Flow chi tiết khi trả lời một câu

Pseudo-code:

```ts
function onAnswerQuestion(isCorrect, questionType) {
  if (isCorrect) {
    combo += 1;
    energy += calculateEnergyGain(combo);

    const baseDamage = getQuestionDamage(questionType);
    const comboMultiplier = getComboMultiplier(combo);
    const petBonus = getPetDamageBonus(activePets);

    const finalDamage = Math.round(baseDamage * comboMultiplier * petBonus);

    applyDamageToEnemy(finalDamage);
  } else {
    combo = 0;

    const penalty = getWrongAnswerPenalty(stage.difficulty);
    player.hearts -= penalty.heartDamage;
    enemy.shield += penalty.bossShieldGain;
  }

  checkBattleState();
}
```

Damage vào enemy:

```ts
function applyDamageToEnemy(damage) {
  if (enemy.shield > 0) {
    const shieldDamage = Math.min(enemy.shield, damage);
    enemy.shield -= shieldDamage;
    damage -= shieldDamage;
  }

  if (damage > 0) {
    enemy.hp = Math.max(0, enemy.hp - damage);
  }
}
```

---

## 18. Flow kết thúc stage

```ts
function checkBattleState() {
  if (enemy.hp <= 0 && hasRemainingQuestions()) {
    enterOverkillMode();
    return;
  }

  if (enemy.hp <= 0 && !hasRemainingQuestions()) {
    completeStage("enemy_defeated");
    return;
  }

  if (!hasRemainingQuestions() && enemy.hp > 0) {
    if (canEnterBonusQuestions()) {
      enterBonusQuestionMode();
      return;
    }

    if (accuracy >= passingScorePercent) {
      completeStage("passed_by_score");
    } else {
      failStage("enemy_survived");
    }
  }
}
```

---

## 19. UI cần hiển thị trong màn battle

Nên có các thành phần sau:

```text
Top area:
- Enemy sprite
- Enemy name
- Enemy HP bar
- Enemy shield bar/icon if shield > 0

Middle area:
- Question content
- Answer options grid

Side / bottom area:
- Pet team popup button
- Energy bar
- Combo counter
- Hearts
```

Khi trả lời đúng:

```text
- Damage number flies up
- Enemy flashes red
- HP bar decreases
- Combo increases
- Energy increases
```

Khi trả lời sai:

```text
- Enemy attacks
- Player heart decreases
- Combo resets
- Enemy shield may increase
```

---

## 20. Cân bằng gameplay

Nguyên tắc cân bằng:

```text
Easy stage: người chơi gần như chắc thắng nếu học đủ.
Normal stage: bắt đầu có áp lực nhẹ.
Hard stage: yêu cầu nhớ tốt hơn, có shield.
Boss stage: cần accuracy cao hơn.
Elite boss: thử thách chính của topic dài.
```

Không nên để battle quá khó vì đây vẫn là app học. Enemy nên tạo cảm giác tiến trình và chiến thắng, không nên làm người chơi bị kẹt lâu.

Đề xuất quan trọng:

1. Stage học từ mới không nên làm người chơi thua nặng.
2. Stage review có thể sai và học lại.
3. Boss nên khó hơn nhưng có bonus question để cứu.
4. Pet mạnh giúp dễ hơn nhưng không thay thế kiến thức.
5. Nếu enemy chết sớm, vẫn nên cho người chơi làm hết câu để đảm bảo học đủ.

---

## 21. Battle config đề xuất hoàn chỉnh

```json
{
  "battleConfig": {
    "enabled": true,
    "basePlayerDamageTarget": 10,
    "hpFormula": "roundUpToNearest10(recommendedQuestionCount * basePlayerDamageTarget * difficultyHpMultiplier)",
    "difficultyHpMultiplier": {
      "easy": 0.9,
      "normal": 1.0,
      "hard": 1.15,
      "boss": 1.3,
      "elite_boss": 1.5
    },
    "baseShieldByDifficulty": {
      "easy": 0,
      "normal": 0,
      "hard": 10,
      "boss": 25,
      "elite_boss": 40
    },
    "questionDamage": {
      "imageChoice": 8,
      "wordMeaningMatch": 10,
      "listeningChoice": 12,
      "contextFillBlank": 14,
      "wordArrangement": 14,
      "typingSpelling": 16,
      "bossMixedChallenge": 18,
      "speedReview": 10
    },
    "comboDamageBonus": [
      { "comboMin": 3, "damageMultiplier": 1.1 },
      { "comboMin": 5, "damageMultiplier": 1.2 },
      { "comboMin": 10, "damageMultiplier": 1.35 },
      { "comboMin": 15, "damageMultiplier": 1.5 }
    ],
    "energyRules": {
      "maxEnergy": 100,
      "correctAnswer": 10,
      "combo5Bonus": 5,
      "perfectAnswerBonus": 5,
      "wrongAnswer": 0
    },
    "wrongAnswerPenaltyByDifficulty": {
      "easy": { "heartDamage": 0, "bossShieldGain": 0, "comboReset": true },
      "normal": { "heartDamage": 1, "bossShieldGain": 0, "comboReset": true },
      "hard": { "heartDamage": 1, "bossShieldGain": 5, "comboReset": true },
      "boss": { "heartDamage": 1, "bossShieldGain": 10, "comboReset": true },
      "elite_boss": { "heartDamage": 1, "bossShieldGain": 15, "comboReset": true }
    },
    "bonusQuestionRule": {
      "enabled": true,
      "maxBonusQuestions": 3,
      "triggerWhenEnemyHpAbove": 0,
      "requiredAccuracyToEnterBonus": 70
    },
    "overkillBonus": {
      "enabled": true,
      "coinPerCorrectAnswer": 2,
      "foodPerCorrectAnswer": 3,
      "extraShardChancePerCorrectAnswer": 0.01,
      "maxExtraShardChance": 0.08
    },
    "victoryRule": {
      "enemyDefeated": true,
      "allowVictoryByPassingScore": true,
      "useBonusQuestionsWhenEnemySurvives": true
    }
  }
}
```

---

## 22. Kết luận

Cơ chế battle với enemy nên được thiết kế như một lớp gamification nằm trên hệ thống học từ vựng:

```text
Question → Correct answer → Damage → Enemy HP decreases → Victory → Reward
```

Cơ chế này giúp mỗi stage có mục tiêu rõ ràng hơn, tăng cảm giác tiến bộ, đồng thời vẫn giữ trọng tâm là học và ôn từ vựng.
