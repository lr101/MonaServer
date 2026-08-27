import 'package:flutter/material.dart';

enum Achievement {

  admin(-1, "Admin", "Group Admin", "assets/achievements/newbie.jpeg",  Colors.purple),
  localContribution(0, "Local Contributor", "Add 10 sticks in a city!", "assets/achievements/local-contributor.jpeg",  Colors.green),
  earlyAdopter(1, "Early Adopter", "You joined in the first year!", "assets/achievements/early-bird.jpeg", Colors.indigoAccent),
  buffed(2, "Mona", "Join the Buffed Lisa group!", "assets/achievements/mona.jpg", Colors.yellow),
  createPin(3, "Stick-It", "Add your first stick!", "assets/achievements/stick-it.jpg", Colors.purpleAccent),
  joinGroup(4, "Team player", " Join your first group!", "assets/achievements/group.jpeg", Colors.lightGreen),
  likes1000(5, "Like plz", "1,000 likes!", "assets/achievements/1000likes.jpeg", Colors.redAccent),
  artist(6, "Artist", "Earn 1000 art likes!", "assets/achievements/art.jpeg", Colors.redAccent),
  traveller(7, "Traveller", "Earn 1000 location likes!", "assets/achievements/traveler.jpeg", Colors.redAccent),
  photographer(8, "Photographer", "Earn 1000 photography likes!", "assets/achievements/photography.jpeg", Colors.redAccent),
  amazing(9, "Certified Awesome", "Amazing! Add 500 sticks!", "assets/achievements/amazing.jpeg", Colors.tealAccent),
  regionalMaster(10, "Regional Master", "Add 100 sticks in one state!", "assets/achievements/regional-master.jpeg", Colors.pink),
  countryMaster(11, "Country Master", "Add 250 sticks in one country!", "assets/achievements/country-master.jpeg", Colors.pink),
  localHero(12, "Local Hero", "Reach the top 3 ranking in a city!", "assets/achievements/local-hero.jpeg", Colors.orange),
  regionalHero(13, "Regional Hero", "Reach the top 3 ranking in a state!", "assets/achievements/regional-hero.jpeg", Colors.orange),
  countryHero(14, "Country Hero", "Reach the top 3 ranking in a country!", "assets/achievements/country-hero.jpeg", Colors.orange),
  worldHero(15, "World Hero", "Reach the top 3 ranking in the world!", "assets/achievements/world-hero.jpeg", Colors.orange);


  const Achievement(
    this.id,
    this.name,
    this.description,
    this.imagePath,
    this.color,);

  final int id;
  final String name;
  final String description;
  final String imagePath;
  final Color color;

  static Achievement getById(int id) {
    return Achievement.values.firstWhere((e) => e.id == id);
  }
}
