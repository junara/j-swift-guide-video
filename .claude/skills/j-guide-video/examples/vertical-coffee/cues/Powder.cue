init kettle@KREST kettle.a=0 pour=0 mug.fill=0 mug.powder=0 mixed=0 jar.lid=0 spoon=1 spoon.full=0 card.exit=0
0.0-.4 card 粉をすくう@0.0-.2|マグに入れる@0.1-.2
0.0 H>gesture~.4
0.0-.3 jar.lid=1~.4
0.0+.3 C>c.jar~.5
0.0+.5 spoon.full=1~.2
0.1 C>c.mug~.6
0.1+.2 spoon.full=0~.3;mug.powder=1~.3
0.1+.9 C>c.away~.5;jar.lid=0~.4
