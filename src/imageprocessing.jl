using Images, ImageFiltering
using FileIO

"""
    images_to_maps(...)

* has nearly the same inputs as convert_image_to_world but there is a directorypath instead of a filepath of one image and
* a targetpath, where you save the 12 maps 
"""
function images_to_maps(dirsourcepath, targetpath = joinpath(@__DIR__, "..","input","world","monthly_maps"),transpose_image = true,  blurred=1, nlongitude=128, limit_ocean = 10, limit_land= 190, limit_seaice=205 )
    
    if isdir(dirsourcepath)
        for (root, dirs, files) in walkdir(dirsourcepath)
            for file in files
                if occursin("world", string(file))
                    filepath = joinpath(@__DIR__, root, file) 
                    world = convert_image_to_world(filepath, transpose_image, blurred, nlongitude, limit_ocean, limit_land, limit_seaice)
                    save_world_by_month(world, string(file), targetpath)
                end
            end
        end
    end
end 

"""
    convert_image_to_world(...)

* imagefile is the filapath of that lanscape we want to convert into our map with dicrete values for each landcover
* transpose_image is nessessary because without transposing each image from NASA website, we would create a 
    symmetrically mirrored map
* imglong and imglat are the longitude and latitude of the input image
* nlongitude is the preferred longitude for the nearest neighbor interpolation
* limit_[...] is the limiting value for the classification from grayscale per landcover, 
    0 <= ocean (5) <= limit_ocean <= land (1) <= limit_land <= ice (2) <= limit_seaice <= snow (3) <= 255
"""
function convert_image_to_world(imagefile, transpose_image=true, blurred=1, nlongitude=128, limit_ocean = 10, limit_land= 190, limit_seaice=210)

    world = FileIO.load(imagefile)
    if transpose_image
        world = transpose(world) 
    end
    (longitude, latitude) = size(world)

    if blurred!=0
        world = imfilter(world, Kernel.gaussian(blurred))
    end

    # from RGB values to grayscale
    grayworld = Gray.(world)
    grayworld = real.(grayworld) .*255 # to get common grayscale from 0 (black) to 255 (white)
    geography = zeros(Int, longitude, latitude)

    for lat = 1:latitude
        for long = 1:longitude
            if grayworld[long, lat] >= 0 && grayworld[long, lat] <= limit_ocean # ocean
                geography[long, lat] = 5
            elseif grayworld[long, lat] > limit_ocean && grayworld[long, lat] <= limit_land # land
                geography[long, lat] = 1
            elseif grayworld[long, lat] > limit_land && grayworld[long, lat] <= limit_seaice # sea ice
                geography[long, lat] = 2
            elseif grayworld[long, lat] > limit_seaice && grayworld[long, lat] <= 256 # snow cover (snow has the highest albedo value)
                geography[long, lat] = 3
            end
        end
    end
  
    geography[:,1] .= mode_for_poles(geography[:,1])
    geography[:,latitude] .= mode_for_poles(geography[:,latitude])
   
    return nn_interpolation(geography, nlongitude)
end

"""
    save_world_by_month(...)

* saves converted maps by their filename.
* thats important because our simulation starts at 21th March, so March's map should be the first one we 
*       read out, April's the second and so on
* we label these maps at the end of their filename with those numbers in directory target_dirpath
"""
function save_world_by_month(array_in, img_filename, target_dirpath)
    if !isdir(joinpath(@__DIR__,target_dirpath))
        mkdir(joinpath(@__DIR__,target_dirpath))
    end 
    
    # Because our simulation begins at 21 March, we have to label March with 1 
    months = Dict([("jan", 11), ("feb", 12), ("mar", 1), ("apr", 2), ("may", 3), ("jun", 4), ("jul", 5), ("aug", 6), ("sep", 7), ("oct", 8), ("nov", 9), ("dec", 10)])
    
    for (key, val) in months
        if occursin(string(key), img_filename)
            (scaledlong, scaledlat) = size(array_in)
            
            new_filename = string("The_World_from_image", scaledlong, "x", scaledlat,"_", val, ".dat") 
            new_filepath = string(joinpath(@__DIR__,target_dirpath, new_filename))
            if !isfile(new_filepath)
                touch(new_filepath) 
            end 

            open(new_filepath,"w") do file 
                for lat = 1:scaledlat
                    for long = 1:scaledlong
                        write(file,string(array_in[long, lat]))
                    end 
                    write(file, "\n")
                end
            end
        end
    end
end

function mode_for_poles(a)
    isempty(a) && throw(ArgumentError("mode is not defined for empty collections"))
    len = length(a)
    r0 = 1
    r1 = 8
    cnts = zeros(Int, 8)
    for i = 1:len
        x = a[i]
        if r0 <= x <= r1
            c = (cnts[x] += 1)
        end
    end
    return findfirst(x -> x == maximum(cnts), cnts) 
end