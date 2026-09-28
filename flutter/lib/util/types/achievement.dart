import 'package:flutter/material.dart';

enum Achievement {
  unknown(
    -1,
    "Achievement",
    "A community achievement.",
    "assets/achievements/mona.jpg",
    Colors.blueGrey,
  ),
  localContribution(
    0,
    "Two countries",
    "Add sticks in two different countries.",
    "assets/achievements/local-contributor.jpeg",
    Colors.green,
  ),
  earlyAdopter(
    1,
    "Retired",
    "This legacy milestone is no longer active.",
    "assets/achievements/early-bird.jpeg",
    Colors.indigoAccent,
  ),
  buffed(
    2,
    "Two groups",
    "Join two groups.",
    "assets/achievements/mona.jpg",
    Colors.yellow,
  ),
  createPin(
    3,
    "Two sticks",
    "Add two sticks.",
    "assets/achievements/stick-it.jpg",
    Colors.purpleAccent,
  ),
  joinGroup(
    4,
    "Team regular",
    "Join five groups.",
    "assets/achievements/group.jpeg",
    Colors.lightGreen,
  ),
  likes1000(
    5,
    "Supporter",
    "Give likes to twenty sticks from other people.",
    "assets/achievements/1000likes.jpeg",
    Colors.redAccent,
  ),
  artist(
    6,
    "Getting noticed",
    "Receive twenty likes on your sticks.",
    "assets/achievements/art.jpeg",
    Colors.redAccent,
  ),
  traveller(
    7,
    "Super supporter",
    "Give likes to two hundred sticks from other people.",
    "assets/achievements/traveler.jpeg",
    Colors.redAccent,
  ),
  photographer(
    8,
    "Fan favorite",
    "Receive likes on two hundred of your sticks.",
    "assets/achievements/photography.jpeg",
    Colors.redAccent,
  ),
  amazing(
    9,
    "Stick collector",
    "Add forty sticks.",
    "assets/achievements/amazing.jpeg",
    Colors.tealAccent,
  ),
  regionalMaster(
    10,
    "Explorer",
    "Add sticks in ten different countries.",
    "assets/achievements/regional-master.jpeg",
    Colors.pink,
  ),
  countryMaster(
    11,
    "Wide-ranging explorer",
    "Add sticks in 25 different countries.",
    "assets/achievements/country-master.jpeg",
    Colors.pink,
  ),
  localHero(
    12,
    "Dedicated collector",
    "Add two hundred sticks.",
    "assets/achievements/local-hero.jpeg",
    Colors.orange,
  ),
  regionalHero(
    13,
    "Community regular",
    "Join ten groups.",
    "assets/achievements/regional-hero.jpeg",
    Colors.orange,
  ),
  countryHero(
    14,
    "Big supporter",
    "Give likes to four hundred sticks from other people.",
    "assets/achievements/country-hero.jpeg",
    Colors.orange,
  ),
  worldHero(
    15,
    "Community favorite",
    "Receive likes on four hundred of your sticks.",
    "assets/achievements/world-hero.jpeg",
    Colors.orange,
  ),
  fourHundredCollector(
    16,
    "Four hundred collector",
    "Add 400 sticks.",
    "assets/achievements/local-hero.jpeg",
    Colors.deepOrange,
  ),
  photoStoryteller(
    17,
    "Photo storyteller",
    "Add photos to two of your sticks.",
    "assets/achievements/photography.jpeg",
    Colors.cyan,
  ),
  albumKeeper(
    18,
    "Album keeper",
    "Add photos to 40 different sticks.",
    "assets/achievements/photography.jpeg",
    Colors.deepOrange,
  ),
  galleryCurator(
    19,
    "Gallery curator",
    "Add photos to 200 different sticks.",
    "assets/achievements/photography.jpeg",
    Colors.deepPurple,
  ),
  seasonedExplorer(
    20,
    "Seasoned explorer",
    "Add sticks in 50 different countries.",
    "assets/achievements/country-master.jpeg",
    Colors.teal,
  ),
  communityBuilder(
    21,
    "Community builder",
    "Join 25 groups.",
    "assets/achievements/group.jpeg",
    Colors.blue,
  ),
  generousSupporter(
    22,
    "Generous supporter",
    "Give likes to 1,000 sticks from other people.",
    "assets/achievements/1000likes.jpeg",
    Colors.indigo,
  ),
  crowdFavorite(
    23,
    "Crowd favorite",
    "Receive 1,000 likes on your sticks.",
    "assets/achievements/art.jpeg",
    Colors.red,
  );

  const Achievement(
    this.id,
    this.name,
    this.description,
    this.imagePath,
    this.color,
  );

  final int id;
  final String name;
  final String description;
  final String imagePath;
  final Color color;

  static Achievement getById(int id) {
    return Achievement.values.firstWhere(
      (e) => e.id == id,
      orElse: () => Achievement.unknown,
    );
  }
}
