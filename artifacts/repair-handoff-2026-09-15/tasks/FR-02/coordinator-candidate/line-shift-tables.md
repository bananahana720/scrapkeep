# FR-02 final line-shift tables and hashes (from the writer's handoff, retained for the TH-01 and HF-09 pass)

Hashes at candidate c87928d6f3e6d6004670f8c7a2b724a2b1d62866: HF-07a md 4e7e240ad9463ebcbdd2638218b5e4d30dd1578840d5bad811e4c986dda026a0; HF-07a csv 206f6aeaf4068240a297bd378be84663cbc91b3937236421ea8e2b0c7edd0bde; HF-07b md 0714ee606e86781a07259787db70b55f8fc70bd3b5287105c767e32e99facc74; HF-08 md 11825772997bd53755a8dc5f036a2cff6890c57a6ab0ed63d81e73ddcd99e0a8.

HF-07a (old = FR-01 revision at d7d2a63): 1-13 unchanged; 14-24 -> 15-25; 25 -> 28; 26-49 -> 29-52; 50 -> 53; 51-66 -> 54-69; 67 -> 70; 68-98 -> 71-101; 99 -> 103; 100 -> 105; 101-107 -> 118-124; 108 -> 125; 109 -> 113 (run.start.character_id); 110-149 -> 126-165; 150 -> 166; 151 -> 104 (run.interruption); 152-159 -> 167-174; 160 -> 175 (outcome new at 176); 161-179 -> 177-195; 180 -> 196; 181-185 -> 197-201 (rejected-key table 193-202); 186-236 -> 203-253; 237-240 -> 262-265; 241 -> 267; 242-250 -> 268-276; 251-265 -> 279-293; 266-269 -> 334-337.

HF-07b (old = FR-01 revision at d7d2a63): 1-14 unchanged (5, 10, 11, 14 rewritten); 15 -> 16; 16-41 -> 17-42; 42-51 -> 45-54; 52 -> 55; 53-101 -> 56-104; 102-107 -> 105-110; 108-112 -> 122-126; 113-119 -> 127-133; 120-246 -> 134-260; 247 -> 261; 248-256 -> 281-289; 257-259 -> 291-293; 260 -> 294; 261-270 -> 296-305; 271-276 -> 306-313; 277-284 -> 314-321; 285-288 -> 361-364.

TH-01 and HF-09 cite HF-07a and HF-07b at earlier bases (cdc10c1 and f7ba966 respectively); compose the FR-01 shift (HF-07a +1 for 108-113, +2 for 114-140, +3 for 141-199, +7 from 200; HF-07b line-neutral) with the table above for HF-09, and the table above alone for TH-01.
