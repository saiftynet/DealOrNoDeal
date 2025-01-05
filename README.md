# DealOrNoDeal
A Terminal Game that tries to use Object::Pad to replicate Deal-Or-No-Deal Game.  While this is in itself 
will hopefully become a reasonably fun implementation, it is mainly a test bed for me to learn
[Object::Pad](https://metacpan.org/dist/Object-Pad) and the eventual Core Object system. 
[Paul Evans](https://metacpan.org/author/PEVANS) was quite keen on feedback from the community regarding
the evolution of the Perl's Internal Object Modelling system based on [Cor](https://github.com/Perl-Apollo/Corinna)
and this requires people to use it, hence this application.


Version 0.001
![image](https://github.com/saiftynet/DealOrNoDeal/blob/main/Screenshots/Version001.png)

### Goals
* A reasonable simulation of [A TV game show](https://en.wikipedia.org/wiki/Deal_or_No_Deal)
* Opportunity to play the Banker or the Player
* The best part of this game is actualy the interactions between the player the host and the banker.
Implementations will start incorporating more and more interactions that involve wit, wisdom and
mind manipulation interactions.

### Project Plan
1. Identify Required Objects, Fields and Methods
2. Build Class to display on a Terminal 
3. Build an Interaction Class

### Version 0.003
![image](https://github.com/saiftynet/DealOrNoDeal/blob/main/Screenshots/dond.gif)
- Split the Game Objects and UI/Display Objects as two separate files
- Now better interactions with the two different modes identified (either choosing Deal or no deal, or choosing a box)


### Version 0.004
- Start of mechanism to handle window size changes
- Improve interaction and unwanted echo of characters when user impatient 
