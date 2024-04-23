%leggo il file excel
T = readtable('ulivi_in_CROP1_RGB.xlsx');
expolat = T.expolat;
expolon = T.expolon;

%trasformo le coordinate nel file excel in intrinseche
[A,RA] = readgeoraster('Seg_CROP1.tif');
proj = RA.ProjectedCRS;
proj.GeographicCRS.Name;
[ xt , yt ] = projfwd( proj , expolat , expolon );

[xInt, yInt] = worldToIntrinsic(RA,xt,yt);

xInt=uint16(xInt);
yInt=uint16(yInt);

%visualizzo i punti in cui sono presenti le chiome del file excel
B = imread("Seg_CROP1.tif");
imshow(B)
hold;
plot(xInt, yInt, 'r.', 'MarkerSize', 25);