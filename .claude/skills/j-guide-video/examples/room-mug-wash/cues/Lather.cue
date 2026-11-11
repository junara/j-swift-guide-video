init <Prepare card.exit=0 sponge.vis=0
0.0-.4 card 水でぬらす@0.0-.2|洗剤をつける@0.1-.1|泡立てる@1.0-.1
0.0 H>gesture~.4
0.0 C>c.wet~.5;csponge=1;water=1
0.1-.1 water=0;C>c.soap+0,90~.4;soap=1
0.1+.2 sponge.foam=.3~.4
1.0-.3 soap=0;C>c.wet+-60,40~.4
1.0 squeeze=1~.2
1.0+.25 squeeze=0~.2
1.1 squeeze=1~.2;sponge.foam=1@1.1+1
1.1+.3 squeeze=0~.2
