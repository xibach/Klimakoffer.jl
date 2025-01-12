using Klimakoffer

Klimakoffer.upscale_albedo(joinpath(@__DIR__,"..","input","albedo"), "albedo128x65.dat",150)

upscaled = Klimakoffer.read_albedo(joinpath(@__DIR__,"..","input","albedo","albedo150x76.dat"), 150, 76)

ref = Klimakoffer.read_albedo(joinpath(@__DIR__,"..","examples","reference_data","albedo","ref_albedo150x76.dat"), 150, 76)

diff = ref-upscaled

res = sum(abs.(diff))

rm(joinpath(@__DIR__,"..","input","albedo","albedo150x76.dat"))