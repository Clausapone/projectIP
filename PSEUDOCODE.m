
%considerare solo le etichette dei 330 alberi nel database
for chioma in chiome:
    if (xInt, yInt) in chioma:
        id_chiome_nel_db.append(chioma.id)   %ESEMPIO: id_chiome_nel_database = [40, 75, ..,  3000, 4000]


for id_chioma=1:len(chiome_nel_db)
    for banda=1:47
        array_valori_ = [ CROP1(row, col, banda) for row,col in L == id_chiome_nel_db(id_chioma)]
        MEDIA(banda) = mean(array_valori_nella_chioma_in_CROP1) % media_iesima_banda_i_esima_chioma 
        STD(banda) = std(array_valori_nella_chioma_in_CROP1)
    end
end