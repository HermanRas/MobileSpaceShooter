we are creating a plan for a mobile game
in godot:
/home/hermanras/Downloads/Godot_v4.7.1
Mobile Space Shooter:
 - the core game is around building your own space ship using shapes rectangles, squeres, triangles, hexagons

 - multiple playser can play on once device we need a character screen with player name and player(charactor) selector

- there are 4 diffrent types right now, hull, armor, shield, hardpoint
- hull gives hp
- shield block give shield
- armor gives armor
- hard point is armor with the support to attach thrustes or weapons

- the ship tiles come in small (0.25) , Medium (0.5), and Large (1) sized each with a build cost relivant to size x base cost.

- each tile type will have a texture, while color is paintable in the hanger (ship builder)

- we will start out with 3 types of thrusters (pulse ,jet ,ion ) thrusters mount to the edge of the shape, depending on direction and shape of thruster is will add speed to that direction

- pulse has a small pulsing speed increase that adds a flat speed in a direction and is the worst, its animation is a small orange puff, level 1,2,3 each improving it a small bit but never better than ion

- jet is better that pulse, its a steady flat speed increase overtime with a red fire trail animation, level 1,2,3 each improving it but never better than ion

- a ion drive truster is the biggest, is has a circular blue blow torch like short flame that increases speed in a curve over time, the longer you apply boost the faster it go's  level 1,2,3 each improving it 

- we will start off with 3 game modes, WaveTime and StoryMode, Creative.

- creative is just a hanger with unlimited resources for you to use, with a test option where you can select level 1-100, be dropped into a random empty map with emamies around that level.

- WaveTime is a classic shoot em up space ship game with bad guys comming in a big timer on screen a running score, every ship you kill will drop a resource according to its type, depending on what type of ship the player is trying to build he can target certain enamies, enamies have a small chanse to drop their gun or thruster, after every round the resources is added to the playsers hanger. in the begining the player will only kill a few then die, upgrade his ship en kill more and get deeper into the game and so on, enamies are generated from a template / blueprint, you can create ships in creative and buy them in WaveTime if you have collected the required resources.

- StoryMode is a hex generated open world with hexagon tiles representing a hexagon map. you start at a space station after buying your first "weak" ship with 1 gun, from the player the map is generated out the closer times are easier and the further tiles are harder some tiles have astroid belts containing astroids with resources, some have distress beacons (with difficalty random based on distance from center -5 or +5), some are blank, some contain traide stations with hangers, at the hanger you will have a shop where you can buy thrusters and guns or a shipt built in creative, game is saved when you return to a hanger, if you die you lose your progress since last hanger. you can combat repair if you have not been shot in the last 10sec, it will restore health of blocks if you have the required resources in your ship but if a block/tile is destroyed you need to return to the hanger to restore it, enamies and astroids drop resources, enamies have a small chanse to drop their gun or thruster, some hangers will have Jobs and other will have shops. picking a job at a hanger from the space station will convert one of the empty tiles in a 6x6 raduis to a job (kill HVT, protect VIP, mine XYZ, keep the zone clear for X Time with some random gen back story) with a reward for complting it, if there is no more free tiles you need to find the next station hanger. not all stations have jobs, shops, hangers. we can pre gen (shop, Bar / job, Hanger and procedurally generate the space stations with random colors), for story mode plan base faction, but note it for v2, faction rep will improve costs or decrease cost or even turn them hostile to you. for story we will add 16 custom tiles starting from the centre and working out, requiring you to level up as you are looking for your wife that was captured by space bandets, after killing the final space station you complete the game, after competion you can continue to explore the maps even thou the story is done. you fly to the edge of the map to open the world map to move between tiles, the edge you approch has no impact on the direction you jump to you can jump to any adjasont tile. tiles save there state to disk when you return to the hanger, a completed tile shope a green tick, other tiles show their icons like astroid belt and beacon and space station as examples, blank tiles have no icon, visited tile that are un completed have a gray background, completed have green, failed save the tile when you return to hanger with a red background but not any of the progress our other tiles they are lost on death.

- guns: single fire gatling, multi fire gatling, , shotgun style flack,mounted cannon, mounted canon turret, emp, rockets, lazers, mines all in with diffrent types of fixed direction , gun swivel 45' turret or 360' turrets

- i have access to a full gemini licenese for art and sprite generation.

- i would like a fair level of detail, for sprite and ui gen you can have a look at at the other game we did , that workflow worked very well :
/home/hermanras/GoogleDrive/DEV/Godot/DEV/AOD_Mobile/Docs/ART_PROMPT.md

for controles i have no idea, i think we plan for a 1 stick and 2 stick option
 - 2 stick just fly's in the direction you move on the left bottom of the screen with a shoot button on the right, there is a switch gun button. during installation of the gun you can set it to auto or manual (turrets 45' and 360' are allways auto), a list of manual guns is shown when you select the switch gun, during switch the game is paused. 1 stick just has a fly button and all guns are auto file

- space station: hanger, shop, bar/job will have a Scrolling Parallax with multiple background, and forgrouands (station), and shop, bar, hanger that can be randomly selected to create a 5x5x5 x3 set of 375 variation of station for you to explore
 