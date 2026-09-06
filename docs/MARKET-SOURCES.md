# Scrapkeep market evidence ledger

Retrieved 5 September 2026, 20:29 UTC by the market research agent. This records a public-data snapshot and a small qualitative sample. The interpretation and original proposals are in [MARKET-RESEARCH.md](MARKET-RESEARCH.md).

## US Steam snapshot

Standard base games, US region, USD, before tax. Review summaries use Steam purchasers only, default off-topic filtering, and separate all-language/English queries. Percentages are calculated from returned counts and rounded to one decimal place. These denominators differ from the qualitative sample below. Direct API results govern this snapshot where cached storefront snippets differ.

| Game / app ID | Release | Current / list price | Positive / total, all languages | Positive / total, English |
| --- | --- | --- | --- | --- |
| Go Mecha Ball / 2008510 | 25 January 2024 | $19.99 / $19.99 | 320 / 372; 86.0% | 249 / 284; 87.7% |
| Rock of Ages 3: Make & Break / 1101360 | 21 July 2020 | $14.99 / $14.99 | 980 / 1,258; 77.9% | 211 / 311; 67.8% |
| Once Upon A KATAMARI / 1880620 | 23 October 2025 | $23.99 / $39.99; 40% sale | 1,224 / 1,341; 91.3% | 945 / 1,024; 92.3% |

Price/release sources: [Go Mecha Ball API](https://store.steampowered.com/api/appdetails?appids=2008510&cc=us&l=english&filters=price_overview,name,release_date), [Rock of Ages 3 API](https://store.steampowered.com/api/appdetails?appids=1101360&cc=us&l=english&filters=price_overview,name,release_date), [Katamari API](https://store.steampowered.com/api/appdetails?appids=1880620&cc=us&l=english&filters=price_overview,name,release_date).

All-language summaries: [Go Mecha Ball reviews API](https://store.steampowered.com/appreviews/2008510?json=1&language=all&purchase_type=steam&num_per_page=0&filter=all), [Rock of Ages 3 reviews API](https://store.steampowered.com/appreviews/1101360?json=1&language=all&purchase_type=steam&num_per_page=0&filter=all), [Katamari reviews API](https://store.steampowered.com/appreviews/1880620?json=1&language=all&purchase_type=steam&num_per_page=0&filter=all). English summaries use the same URLs with `language=english`.

Review totals are not player totals, market share, sales estimates, or measures of prospective interest in Scrapkeep. Franchise recognition, years on sale, regional audiences, publisher reach, and distribution differ. No causal explanation for the language-level rating differences was established.

## Qualitative review sample

The researcher read the first five returned English reviews for each polarity for each game: **30 total, five positive and five negative per game**. Queries used `purchase_type=all`, `filter=all`, `day_range=365`, `num_per_page=5`, default off-topic filtering, and the relevant `review_type`. Steam describes this ordering through helpfulness and sliding time windows. This is purposive and polarity-balanced; it intentionally overrepresents negative reviews relative to the overall ratings. Some copies were acquired outside Steam. It does not estimate issue prevalence. [Steamworks review API documentation](https://partner.steamgames.com/doc/store/getreviews).

An initial exploratory query used an out-of-range `day_range=36500`. The researcher corrected it to the documented maximum of 365 and reran the queries; the first returned entries were unchanged. The valid queries and IDs below define this sample. The parent did not independently reread all 30 reviews; analysis is attributed to the delegated researcher. Full copyrighted review text is not reproduced here.

| Game | Observations in this sample | Example sources |
| --- | --- | --- |
| Go Mecha Ball | Positive anecdotes describe rolling weight, expressive animation, music, and build variety. Two of five negatives and one of five positives discuss repetition or delayed diversity. Two negatives report rebinding problems; two report deteriorating performance. | [Positive review 216205945](https://steamcommunity.com/profiles/76561198006735523/recommended/2008510/), [positive 204021088](https://steamcommunity.com/profiles/76561198302346750/recommended/2008510/), [negative 205024316](https://steamcommunity.com/profiles/76561198211205444/recommended/2008510/), [negative 222315204](https://steamcommunity.com/profiles/76561198411590156/recommended/2008510/), [negative 205499846](https://steamcommunity.com/profiles/76561198006332787/recommended/2008510/) |
| Rock of Ages 3 | Positive anecdotes value the unusual concept, humor, boulders, units, bosses, and modes. Two of five negatives criticize balance. One describes unrecoverable stuck states; another objects to progression requiring repetition. | [Positive review 232508517](https://steamcommunity.com/profiles/76561198135991253/recommended/1101360/), [positive 207651748](https://steamcommunity.com/profiles/76561199870364865/recommended/1101360/), [negative 224879036](https://steamcommunity.com/profiles/76561199441056593/recommended/1101360/), [negative 204684049](https://steamcommunity.com/profiles/76561198976745759/recommended/1101360/), [negative 225699556](https://steamcommunity.com/profiles/76561198151069537/recommended/1101360/) |
| Once Upon A KATAMARI | Positive anecdotes value charm, familiar flow, and control improvements. Four of five negatives plus one of five positives describe awkward collisions, stuck states, or disrupted rolling. One negative criticizes visible growth/disappearing objects; two criticize repetition or thematic distribution. | [Positive review 207426742](https://steamcommunity.com/profiles/76561198041994478/recommended/1880620/), [negative 218661233](https://steamcommunity.com/profiles/76561198091258861/recommended/1880620/), [negative 226680828](https://steamcommunity.com/profiles/76561198067681717/recommended/1880620/), [negative 214677200](https://steamcommunity.com/profiles/76561198026719448/recommended/1880620/) |

These are player reports. No alleged defect, historical software state, performance issue, or balance problem was independently reproduced. A positive review can contain criticism. Brief joke reviews supplied little design evidence. No games were installed or played for this pass.

### Review IDs in returned order

| Game | Positive recommendation IDs | Negative recommendation IDs |
| --- | --- | --- |
| Go Mecha Ball | 214271877, 204021088, 216405857, 216205945, 204264815 | 205024316, 222315204, 205499846, 229730053, 204305835 |
| Rock of Ages 3 | 205010992, 231786996, 232508517, 207651748, 221611031 | 232934042, 223558158, 204684049, 224879036, 225699556 |
| Once Upon A KATAMARI | 207421889, 207426742, 207904915, 207507641, 207506029 | 218661233, 226680828, 214677200, 220234252, 209002325 |

Reproduction example: [Go Mecha Ball positive sample query](https://store.steampowered.com/appreviews/2008510?json=1&language=english&purchase_type=all&filter=all&day_range=365&num_per_page=5&review_type=positive). Substitute the other app IDs and `review_type=negative` for the other strata. Results can change after the retrieval date; retained recommendation IDs identify the inspected entries.

## Interpretation for further discovery

The useful hypotheses are to protect uninterrupted rolling, make growth visible, introduce behavior-changing loot early, and sustain readable controls/effects throughout the chosen expedition length. These observations do not prove a market gap or authorize a feature roadmap. The earlier 28-review sample across Roboquest, Risk of Rain 2, and Deathtrap used a different method and remains separate in [DISCOVERY.md](DISCOVERY.md).
