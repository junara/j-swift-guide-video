init <Load
0.0+.3 H>mw.handle~.45
0.0+.35 mw.open=0~.6
0.1 H>mw.start+-10,-16~.3;mw.disp=600W
0.2+.1 mw.disp=2:00
0.2+.45 P mw.start;mw.on=1~.2;mw.disp=cd 2:00 0:00@1.0;rice.heat=1@1.0;dish.shift=wave 9 .95@1.0;timer timer 2分@1.0;say timer+0,-140 待ち時間は短縮しています@1.0+.4;pulse mw.disp@1.0
0.2+1.4 H>gesture~.6
1.0 mw.on=0~.25;mw.disp=0:00;say mw.top チン！@1.1-.1;pulse mw.disp@1.0+.8
1.1-.1 H>mw.handle~.4;mw.open=1~.4
1.1+.7 H>dish.gripL~.4;dish.in=0
1.1+.77 dish@PLATE~.5;steam dish.top
