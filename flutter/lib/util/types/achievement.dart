import 'package:flutter/material.dart';

enum Achievement {
  admin(
    -1,
    "Admin",
    "Group Admin",
    "assets/achievements/newbie.jpeg",
    Colors.purple,
  ),
  localContribution(
    0,
    "First place",
    "Add a stick in your first place.",
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
    "First crew",
    "Join your first group.",
    "assets/achievements/mona.jpg",
    Colors.yellow,
  ),
  createPin(
    3,
    "First stick",
    "Add your first stick.",
    "assets/achievements/stick-it.jpg",
    Colors.purpleAccent,
  ),
  joinGroup(
    4,
    "Team regular",
    "Join three groups.",
    "assets/achievements/group.jpeg",
    Colors.lightGreen,
  ),
  likes1000(
    5,
    "Supporter",
    "Give likes to ten sticks from other people.",
    "assets/achievements/1000likes.jpeg",
    Colors.redAccent,
  ),
  artist(
    6,
    "Getting noticed",
    "Receive ten likes on your sticks.",
    "assets/achievements/art.jpeg",
    Colors.redAccent,
  ),
  traveller(
    7,
    "Super supporter",
    "Give likes to fifty sticks from other people.",
    "assets/achievements/traveler.jpeg",
    Colors.redAccent,
  ),
  photographer(
    8,
    "Fan favorite",
    "Receive likes on fifty of your sticks.",
    "assets/achievements/photography.jpeg",
    Colors.redAccent,
  ),
  amazing(
    9,
    "Stick collector",
    "Add ten sticks.",
    "assets/achievements/amazing.jpeg",
    Colors.tealAccent,
  ),
  regionalMaster(
    10,
    "Explorer",
    "Add sticks in three different places.",
    "assets/achievements/regional-master.jpeg",
    Colors.pink,
  ),
  countryMaster(
    11,
    "Wide-ranging explorer",
    "Add sticks in ten different places.",
    "assets/achievements/country-master.jpeg",
    Colors.pink,
  ),
  localHero(
    12,
    "Dedicated collector",
    "Add fifty sticks.",
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
    "Give likes to one hundred sticks from other people.",
    "assets/achievements/country-hero.jpeg",
    Colors.orange,
  ),
  worldHero(
    15,
    "Community favorite",
    "Receive likes on one hundred of your sticks.",
    "assets/achievements/world-hero.jpeg",
    Colors.orange,
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
    return Achievement.values.firstWhere((e) => e.id == id);
  }
}
