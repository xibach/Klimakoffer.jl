using Klimakoffer

ref = Klimakoffer.read_geography(joinpath(@__DIR__,"..","examples","reference_data","world","ref_The_World_Outline128x65.dat"),128,65) #original outline from Klimakoffer

Klimakoffer.save_outline_from_path(joinpath(@__DIR__,"..","input","world"), "The_World128x65.dat", 128)

outline = Klimakoffer.read_geography(joinpath(@__DIR__,"..","input","world","The_World_Outline128x65.dat"), 128, 65) # calculated outline from implemented function 

diff = ref - outline

res = sum(abs.(diff))
