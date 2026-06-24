# Reward Mechanism Explanation

This document explains the reward system used for the vocabulary-learning creature collection game. The system is designed for a stage-based learning flow inspired by Duolingo/Candy Crush, combined with creature collection, egg hatching, evolution, and star upgrades.

The learning content is organized into topics, and each topic contains multiple stages such as `learn`, `review`, and `final_review`. Topics can have different lengths, for example short topics may have 3 stages, while larger topics may have 7, 9, 11, or more stages. Because of this, the reward system uses both **stage difficulty** and **topic length** to calculate fair rewards.

---

## 1. Reward Items

The reward system includes the following items:

| Reward Item | Purpose |
|---|---|
| `coin` | Used mainly for upgrading creature stars and evolution costs. |
| `food` | Used to feed creatures and increase creature growth/progress. |
| `evolutionStone` | Used to evolve creatures from baby to teen, and from teen to adult. |
| `creatureShard` | Used together with coins to upgrade creature stars. |
| `commonEgg` | A normal island egg. It can hatch creatures of all rarities, but mostly common creatures. |
| `rareEgg` | A better egg with higher chances to hatch rare, epic, or legendary creatures. |

Recommended value order:

```text
food < coin < common shard < rare shard < epic shard < legendary shard < evolution stone < common egg < rare egg
```

---

## 2. Stage Difficulty

Each stage should be assigned a difficulty level. The difficulty affects reward size and drop rates.

| Difficulty | Typical Stage Type | Description |
|---|---|---|
| `easy` | `learn` | The player learns new words or does simple recognition tasks. |
| `normal` | early `review` | The player reviews recently learned words. |
| `hard` | later `review` | The player answers harder questions such as sentence completion, listening, or mixed quizzes. |
| `boss` | short/medium `final_review` | The final review of a topic. |
| `elite_boss` | long-topic `final_review` or milestone | The final review of a long topic or major island milestone. |

Recommended difficulty mapping:

```text
learn                         -> easy
review near the start          -> normal
review near the middle/end     -> hard
final_review in 3-5 stage topic -> boss
final_review in 7+ stage topic  -> elite_boss
```

---

## 3. Base Reward by Difficulty

### Easy Stage

Used for most `learn` stages.

```json
{
  "coin": { "min": 8, "max": 14 },
  "food": { "min": 10, "max": 18 },
  "evolutionStone": { "chance": 0.0, "amount": 0 },
  "creatureShard": { "chance": 0.25, "amount": { "min": 1, "max": 1 } },
  "commonEgg": { "chance": 0.0 },
  "rareEgg": { "chance": 0.0 }
}
```

Easy stages mostly give coins and food. Creature shards are possible but not guaranteed. Eggs and evolution stones should not normally drop here.

---

### Normal Stage

Used for early review stages.

```json
{
  "coin": { "min": 12, "max": 20 },
  "food": { "min": 16, "max": 26 },
  "evolutionStone": { "chance": 0.05, "amount": 1 },
  "creatureShard": { "chance": 0.4, "amount": { "min": 1, "max": 2 } },
  "commonEgg": { "chance": 0.0 },
  "rareEgg": { "chance": 0.0 }
}
```

Normal stages give slightly better resources and introduce a small chance of evolution stones.

---

### Hard Stage

Used for harder review stages.

```json
{
  "coin": { "min": 18, "max": 30 },
  "food": { "min": 24, "max": 38 },
  "evolutionStone": { "chance": 0.1, "amount": 1 },
  "creatureShard": { "chance": 0.6, "amount": { "min": 1, "max": 3 } },
  "commonEgg": { "chance": 0.03 },
  "rareEgg": { "chance": 0.0 }
}
```

Hard stages may rarely drop a common egg. They are also a reliable source of creature shards.

---

### Boss Stage

Used for final topic reviews in short or medium topics.

```json
{
  "coin": { "min": 35, "max": 55 },
  "food": { "min": 45, "max": 70 },
  "evolutionStone": { "chance": 0.35, "amount": { "min": 1, "max": 2 } },
  "creatureShard": { "chance": 1.0, "amount": { "min": 3, "max": 6 } },
  "commonEgg": { "chance": 0.18 },
  "rareEgg": { "chance": 0.03 }
}
```

Boss stages always give creature shards and have meaningful chances to drop eggs.

---

### Elite Boss Stage

Used for final reviews of large topics or island milestones.

```json
{
  "coin": { "min": 60, "max": 90 },
  "food": { "min": 80, "max": 120 },
  "evolutionStone": { "chance": 0.6, "amount": { "min": 2, "max": 4 } },
  "creatureShard": { "chance": 1.0, "amount": { "min": 5, "max": 10 } },
  "commonEgg": { "chance": 0.35 },
  "rareEgg": { "chance": 0.08 }
}
```

Elite boss stages are the most valuable normal learning rewards. They should feel exciting and should be used sparingly.

---

## 4. Creature Shard Drop Rate

When a stage drops a creature shard, the game should roll the shard rarity using this table:

```json
{
  "common": 0.68,
  "rare": 0.22,
  "epic": 0.08,
  "legendary": 0.02
}
```

This means common creature shards are easy to obtain, while legendary creature shards are very rare.

Example:

If a hard stage has a `60%` chance to drop creature shards, and the stage successfully drops shards, the rarity of those shards is then selected using the rarity table above.

---

## 5. Egg Drop Rules

Eggs should only appear in harder stages, boss stages, elite boss stages, or island milestones.

### Common Egg Drop Chance

| Difficulty | Drop Chance |
|---|---:|
| `easy` | 0% |
| `normal` | 0% |
| `hard` | 3% |
| `boss` | 18% |
| `elite_boss` | 35% |

### Rare Egg Drop Chance

| Difficulty | Drop Chance |
|---|---:|
| `easy` | 0% |
| `normal` | 0% |
| `hard` | 0% |
| `boss` | 3% |
| `elite_boss` | 8% |

Rare eggs should feel special and should not be obtainable too often from normal stages.

---

## 6. Egg Hatch Rate

### Common Egg

```json
{
  "common": 0.72,
  "rare": 0.2,
  "epic": 0.07,
  "legendary": 0.01
}
```

A common egg usually hatches common creatures, but it still has a small chance to hatch epic or legendary creatures.

### Rare Egg

```json
{
  "common": 0.35,
  "rare": 0.4,
  "epic": 0.2,
  "legendary": 0.05
}
```

A rare egg is much more valuable because it has a higher chance to hatch rare, epic, and legendary creatures.

---

## 7. Correct-answer Bonus

The number of correct answers directly determines whether the stage is passed
and the final reward. Stage stars are not used.

```text
correctRate = correctAnswers / totalQuestions
```

| Correct answers | Result | Reward Multiplier | Extra Shard Chance |
|---|---:|---:|---:|
| Below 60% | Failed | No reward | 0% |
| At least 60%, below 80% | Passed | 0.85x | 0% |
| At least 80%, not perfect | Passed | 1.0x | 5% |
| All questions correct | Perfect | 1.25x | 12% |

This encourages players to replay stages for better performance without making progression feel blocked.

---

## 8. Topic Length Multiplier

Longer topics require more learning effort, so they should give better rewards.

| Total Stages | Topic Type | Multiplier |
|---:|---|---:|
| 3 | Short Topic | 0.85x |
| 5 | Small Topic | 1.0x |
| 7 | Medium Topic | 1.15x |
| 9 | Large Topic | 1.3x |
| 11 | Very Large Topic | 1.45x |
| 13 | Mega Topic | 1.6x |

This is important because a 3-stage topic should not give the same total reward as an 11-stage topic.

---

## 9. Final Reward Formula

The recommended formula is:

```text
finalReward = baseReward
            × stageDifficultyMultiplier
            × topicLengthMultiplier
            × performanceMultiplier
```

Example:

```text
Base coin roll: 24
Stage difficulty: hard -> 1.5x
Topic length: 7 stages -> 1.15x
Performance: all questions correct -> 1.25x

Final coin = 24 × 1.5 × 1.15 × 1.25 = 51.75
Final coin = 52
```

For integer rewards, use rounding:

```text
finalReward = round(calculatedReward)
```

---

## 10. Star Upgrade Cost

Each creature can be upgraded up to 5 stars. Star upgrades require both coins and creature shards.

### Common Creature

| To Star | Coin | Shard |
|---:|---:|---:|
| 1 | 50 | 5 |
| 2 | 120 | 10 |
| 3 | 250 | 20 |
| 4 | 450 | 35 |
| 5 | 750 | 55 |

Total: `1,620 coins` and `125 shards`.

### Rare Creature

| To Star | Coin | Shard |
|---:|---:|---:|
| 1 | 80 | 8 |
| 2 | 200 | 16 |
| 3 | 420 | 32 |
| 4 | 750 | 55 |
| 5 | 1,200 | 85 |

Total: `2,650 coins` and `196 shards`.

### Epic Creature

| To Star | Coin | Shard |
|---:|---:|---:|
| 1 | 150 | 10 |
| 2 | 350 | 22 |
| 3 | 750 | 45 |
| 4 | 1,300 | 75 |
| 5 | 2,100 | 120 |

Total: `4,650 coins` and `272 shards`.

### Legendary Creature

| To Star | Coin | Shard |
|---:|---:|---:|
| 1 | 300 | 15 |
| 2 | 700 | 35 |
| 3 | 1,500 | 70 |
| 4 | 2,600 | 120 |
| 5 | 4,200 | 200 |

Total: `9,300 coins` and `440 shards`.

---

## 11. Evolution Cost

Evolution uses coins and evolution stones. Shards are mainly reserved for star upgrades.

### Common Creature

| Evolution | Coin | Evolution Stone |
|---|---:|---:|
| Baby to Teen | 200 | 3 |
| Teen to Adult | 500 | 8 |

### Rare Creature

| Evolution | Coin | Evolution Stone |
|---|---:|---:|
| Baby to Teen | 350 | 5 |
| Teen to Adult | 800 | 12 |

### Epic Creature

| Evolution | Coin | Evolution Stone |
|---|---:|---:|
| Baby to Teen | 600 | 8 |
| Teen to Adult | 1,400 | 20 |

### Legendary Creature

| Evolution | Coin | Evolution Stone |
|---|---:|---:|
| Baby to Teen | 1,200 | 15 |
| Teen to Adult | 3,000 | 40 |

---

## 12. Example Reward Flow for a 7-Stage Topic

| Stage | Type | Difficulty | Reward Role |
|---:|---|---|---|
| 1 | `learn` | `easy` | Small coin and food reward. |
| 2 | `review` | `normal` | Coin, food, shard chance. |
| 3 | `learn` | `easy` | Small coin and food reward. |
| 4 | `review` | `hard` | Better coin, food, shard chance, small stone chance. |
| 5 | `learn` | `easy` | Small coin and food reward. |
| 6 | `review` | `hard` | Better reward and tiny common egg chance. |
| 7 | `final_review` | `boss` or `elite_boss` | Big reward, guaranteed shards, egg chance. |

---

## 13. Design Goals

This reward system is designed around the following goals:

1. **Players always get something useful**  
   Coins and food appear often so every stage feels rewarding.

2. **Creature shards create long-term collection goals**  
   Common shards appear often, while epic and legendary shards remain rare.

3. **Evolution stones feel valuable**  
   They are not too common and are mainly obtained from harder stages or bosses.

4. **Eggs feel exciting**  
   Eggs are mainly tied to boss stages, elite boss stages, and milestones.

5. **Rare creatures keep long-term value**  
   Rare, epic, and legendary creatures are harder to star-up and evolve, so they remain valuable for longer.

6. **Long topics reward more effort**  
   Topic length multiplier ensures that larger topics give better total rewards.

---

## 14. Balancing Notes

Recommended economy balance:

```text
coin should be easy to earn
food should be very easy to earn
creature shards should be slower than coins
rare/epic/legendary shards should be much slower than common shards
evolution stones should be limited
eggs should feel special
rare eggs should feel very special
```

Avoid giving too many eggs from normal stages. If players receive eggs too frequently, hatching loses excitement and creature rarity becomes less meaningful.

Avoid making legendary creatures too easy to upgrade. Legendary creatures should be long-term goals, not short-term rewards.

---

## 15. Recommended Gameplay Loop

```text
Play a learning stage
-> Earn coin and food
-> Sometimes get creature shards
-> Complete hard reviews and boss stages
-> Sometimes receive evolution stones or eggs
-> Hatch island creatures
-> Use shards and coins to upgrade stars
-> Use stones and coins to evolve creatures
-> Stronger creatures provide better learning buffs
-> Player continues learning to collect and improve more creatures
```
