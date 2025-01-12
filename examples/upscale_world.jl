using Klimakoffer

Klimakoffer.upscale_world(joinpath(@__DIR__,"..","input","world"), "The_World128x65.dat",150)

upscaled = Klimakoffer.read_geography(joinpath(@__DIR__,"..","input","world","The_World150x76.dat"), 150, 76)

ref = Klimakoffer.read_geography(joinpath(@__DIR__,"..","examples","reference_data","world","ref_The_World150x76.dat"), 150, 76)

diff = ref-upscaled

res = sum(abs.(diff))
