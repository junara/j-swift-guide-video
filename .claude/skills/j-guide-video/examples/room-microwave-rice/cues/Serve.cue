init <Heat
0.0-.4 card ラップを外す@0.0-.2|ほぐす@0.1-.1|お茶わんに盛る@0.2-.1;steam dish.top@0.2+1.1;steam c.dish@0.2+1.1
0.0 H>gesture~.4
0.0+.35 C>c.knot~.5;rice.wrap=0@0.1-.4;film=1~.3
0.1-.4 film=0~.5
0.1-.05 C>c.away~.4;tool=1;stick.open=.35
0.1+.35 C>c.rice~.4;C.dx=wave 65 .5@0.2;stick.open=wave .2 .35@0.2;rice.loose=1@0.2-.1
0.2 scoop=1;rice.amount=.5~.15;stick.open=.08
0.2+.5 C>c.bowl~.5;scoop=0;chawan.fill=.5~.2;steam bowl.top;steam c.bowl.top
0.2+1.0 C>c.rice~.45;stick.open=.35
0.2+1.05 scoop=1;rice.amount=0~.15;stick.open=.08
0.2+1.55 C>c.bowl~.5;scoop=0;chawan.fill=1~.2;stick.open=.35
0.2+2.2 C>c.away~.5
1.0 say c.hot 熱いので注意
1.1 shrink bowl.top~.4;H>rest~.4;smile=1~.3;check bowl.badge
