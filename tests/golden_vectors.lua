-- Locked milestone-2 vectors calculated with an independent JavaScript
-- reference implementation using Uint32/Math.imul operations.
return {
  hash = {
    digestEmpty = {
      words = { 1766246582, 2590986623, 1008748721, 3095343324 },
      hex = "6946C8B69A6F517F3C2048B1B87F30DC",
    },
    seedMySeed = {
      words = { 2673526330, 2305549061, 2689801500, 916138135 },
      hex = "9F5AC63A896BE305A0531D1C369B2897",
    },
    seedRace = {
      words = { 3725295803, 3038039001, 2188518488, 1837843683 },
      hex = "DE0B80BBB514CBD9827224586D8B44E3",
    },
  },
  streams = {
    wildGlobal = {
      words = { 2633747276, 2998266192, 1470139603, 2073012410 },
      hex = "9CFBCB4CB2B5E95057A08CD37B8FA8BA",
    },
    starters = {
      words = { 1282469911, 2289884910, 1293952553, 2706269545 },
      hex = "4C70F017887CDEEE4D202629A14E6569",
    },
  },
  nextU32 = {
    4244736558, 2052928304, 2822316631, 4049732850, 3264392326,
    117167927, 2739979778, 3660348236, 1014549837, 3155039993,
  },
  nextInt151 = { 21, 104, 94, 129, 35, 82, 68, 121, 15, 90 },
  shuffle10 = { 1, 2, 4, 6, 7, 5, 3, 8, 10, 9 },
}
