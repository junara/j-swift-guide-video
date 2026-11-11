init <Scrub card.enter=0
0.0 card 泡を流す@0.0;H>gesture~.3
0.0 C>c.away~.5;csponge=0;sponge.foam=0;sponge.vis=1
0.0+.2 water=1;water.mug=1;mug.foam=0@0.1+.3;wet=1~.3
0.1+.2 water=0
1.0 shrink mug.top~.4;H>towel.grip~.6
1.0+.5 towel@WIPE~.5;H.dx=wave 30 .5@1.1+.6
1.1+.6 towel@TOWEL~.5;wet=0~.3;shine=1~.3
1.1+.9 check mug.badge;smile=1~.3
