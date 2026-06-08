-- Bundled crossword puzzles
-- grid: '#' = black cell, letter = solution letter (uppercase)
-- Numbers are computed automatically from grid topology.

local PUZZLES = {
    -- Puzzle 1: 5×5
    {
        title = "Puzzle 1",
        grid  = {
            "STEAM",
            "LAYER",
            "A#E#A",
            "PRISM",
            "#ENDS#",
        },
        clues_across = {
            [1] = "Hot vapour",
            [6] = "Stratum",
            [7] = "Optical device",
            [8] = "Concludes",
        },
        clues_down = {
            [1] = "Musical composition",
            [2] = "Consume",
            [3] = "Expressive art",
            [4] = "Myself",
            [5] = "Animal shelter",
        },
    },
    -- Puzzle 2: 7×7
    {
        title = "Puzzle 2",
        grid  = {
            "BLANKET",
            "L#A#O#E",
            "ICEBERG",
            "N#E#G#R",
            "DETAIL#",
            "#I#A#I#",
            "FIGURE#",
        },
        clues_across = {
            [1]  = "Bed covering",
            [5]  = "Frozen mass in sea",
            [9]  = "Small particular",
            [11] = "Shape or form",
        },
        clues_down = {
            [1]  = "Illuminate",
            [2]  = "Frozen water",
            [3]  = "Piece of music",
            [4]  = "Attempt",
            [6]  = "Move fast",
            [7]  = "Organ of sight",
            [8]  = "Permit",
        },
    },
    -- Puzzle 3: 7×7
    {
        title = "Puzzle 3",
        grid  = {
            "CASTLE#",
            "A#E#O#A",
            "PLANET#",
            "E#I#A#R",
            "#RIVER#",
            "F#E#T#E",
            "FOREST#",
        },
        clues_across = {
            [1]  = "Fortified building",
            [5]  = "World orbiting star",
            [8]  = "Flowing water",
            [11] = "Wooded land",
        },
        clues_down = {
            [1]  = "Feline animal",
            [2]  = "Cereal plant",
            [3]  = "Wager",
            [4]  = "Lean",
            [6]  = "Consume food",
            [7]  = "Not difficult",
            [9]  = "Also",
        },
    },
    -- Puzzle 4: 9×9
    {
        title = "Puzzle 4",
        grid  = {
            "CHAMPION#",
            "A#O#E#O#A",
            "RESULTS##",
            "A#N#I#U#I",
            "COMPLETE#",
            "T#T#R#D#N",
            "#STUDENT#",
            "#E#C#E#A#",
            "#REACHED#",
        },
        clues_across = {
            [1]  = "Contest winner",
            [5]  = "Outcomes",
            [9]  = "Fully done",
            [11] = "Learner",
            [12] = "Arrived at",
        },
        clues_down = {
            [1]  = "Cart horse",
            [2]  = "Honour or praise",
            [3]  = "Connect",
            [4]  = "Written name",
            [6]  = "Rodent",
            [7]  = "First woman (Bible)",
            [8]  = "Cereal grass",
        },
    },
    -- Puzzle 5: 5×5 (simple)
    {
        title = "Puzzle 5",
        grid  = {
            "BRAVE",
            "R#I#E",
            "OXIDE",
            "W#E#D",
            "SNARE",
        },
        clues_across = {
            [1] = "Courageous",
            [4] = "Chemical compound",
            [7] = "Trap",
        },
        clues_down = {
            [1] = "Alcoholic drink",
            [2] = "Salute",
            [3] = "Greet with waves",
            [5] = "Concept",
            [6] = "Antlered animal",
        },
    },
}

return PUZZLES
