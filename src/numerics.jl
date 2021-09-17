
#Mapping functions
##################
# function index2d(k,nx)
#     j = floor(Int,(k-1)/nx)+1
#     # TODO: add consistency check with ny?
#     return k-(j-1)*nx,j 
# end

function index1d(i,j,nx)
    # TODO: add consistency check with ny?
    return i+(j-1)*nx
end


"""
    compute_equilibrium!(...)

RelError is the tolerance for global temperature equilibrium.
"""
function compute_equilibrium!(discretization; maxYears=100, RelError=2e-5)
    @unpack mesh, model, L, U, p, NT, AnnualTemp, RHS, LastRHS  = discretization
    @unpack nx, dof = mesh

    GlobTemp = oldGlobTemp = computeMeanTemp(view(AnnualTemp, :, NT), mesh)

    println("year","  ","GlobTemp")
    println(0,"  ",oldGlobTemp)

    for year in 1:maxYears
        GlobTemp = 0.0
        for time_step in 1:NT
            old_time_step = (time_step == 1) ? NT : time_step - 1
            UpdateRHS!(RHS, mesh, NT, time_step, view(AnnualTemp, :, old_time_step), model, LastRHS)
                        
            AnnualTemp[:, time_step] = U\(L\RHS[p])

            AnnualTemp[1:nx, time_step] .= AnnualTemp[1, time_step]
            AnnualTemp[dof-nx+1:dof, time_step] .= AnnualTemp[dof, time_step]

            GlobTemp += computeMeanTemp(view(AnnualTemp, :, time_step), mesh)
        end
        GlobTemp = GlobTemp/NT
        println(year,"  ",GlobTemp)
        
        if (abs(GlobTemp-oldGlobTemp)<RelError)
            println("EQUILIBRIUM REACHED!")
            break
        end
        
        oldGlobTemp = GlobTemp
    end

    return GlobTemp
end



"""
Computes mean temperature in the globe at a specific time
"""
function computeMeanTemp(Temp,mesh)
    @unpack nx,ny,area,dof = mesh

    MeanTemp = 0.0
    
    # Contribution of inner points
    for j=2:ny-1
        for i=1:nx
            row_idx = index1d(i,j,nx)
            MeanTemp += area[j] * Temp[row_idx]
        end
    end

    # Poles
    MeanTemp += area[1] * (Temp[1] + Temp[dof]) 

    return MeanTemp
end

function ComputeMatrix(mesh,NT,model)
    @unpack nx,ny,dof,h,sh2,geom,csc2,cot,area = mesh
    @unpack D_DiffCoeff,C_HeatCapacity,B_coeff = model
    A    = zeros(Float64,dof,dof)
    # Inner DOFs (c coefficients are divided by h^2)
    for j=2:ny-1
        for i=1:nx

            # Compute coefficients
            c0 = 2 * sh2 * D_DiffCoeff[i,j] * (1 + csc2[j]) + 2 * C_HeatCapacity[i,j] * NT + B_coeff

            # Get diffusion coefficient 
            if (i == 1) # Periodic BC
                dPhi = (D_DiffCoeff[2,j] - D_DiffCoeff[nx,j]) / (2 * h)
            elseif (i == nx) # Periodic BC
                dPhi = (D_DiffCoeff[1,j] - D_DiffCoeff[nx-1,j]) / (2 * h)
            else # Inner DOFs
                dPhi = (D_DiffCoeff[i+1,j] - D_DiffCoeff[i-1,j]) / (2 * h)
            end

            c1 = sh2 * csc2[j] * (D_DiffCoeff[i,j] - 0.5 * h * dPhi)
            c3 = sh2 * csc2[j] * (D_DiffCoeff[i,j] + 0.5 * h * dPhi)

            dTheta= (D_DiffCoeff[i,j+1] - D_DiffCoeff[i,j-1]) / (2 * h)
            c2 = sh2 * (D_DiffCoeff[i,j] - 0.5 * h * (D_DiffCoeff[i,j] * cot[j] + dTheta))
            c4 = sh2 * (D_DiffCoeff[i,j] + 0.5 * h * (D_DiffCoeff[i,j] * cot[j] + dTheta))

            # Fill matrix A
            row_idx = index1d(i,j,nx)
            col_idx_c0 = row_idx
            
            if (i==1) # Periodic BC
                col_idx_c1 = index1d(nx,j,nx)
                col_idx_c3 = row_idx + 1
            elseif (i==nx) # Periodic BC
                col_idx_c1 = row_idx - 1
                col_idx_c3 = index1d(1,j,nx)
            else
                col_idx_c1 = row_idx - 1
                col_idx_c3 = row_idx + 1
            end
            col_idx_c2 = row_idx - nx
            col_idx_c4 = row_idx + nx

            A[row_idx,col_idx_c0] = c0
            A[row_idx,col_idx_c1] = -c1
            A[row_idx,col_idx_c2] = -c2
            A[row_idx,col_idx_c3] = -c3
            A[row_idx,col_idx_c4] = -c4

            # Get RHS
            # RHS[row_idx] = -(c0 * Temp[col_idx_c0] - c1 * Temp[col_idx_c0] - c2 * Temp[col_idx_c2] - c3 * Temp[col_idx_c3] - c4 * Temp[col_idx_c4]) + 4 * C_HeatCapacity[i,j]
        end
    end

    # Poles
    Tarea = area[1] + area[2]

    DT2np = zeros(Float64,nx)
    DT2sp = zeros(Float64,nx)
    for i=1:nx
        DT2np[i] = (area[1] * D_DiffCoeff[1,1]  + area[2] * D_DiffCoeff[i,2]) / Tarea 
        DT2sp[i] = (area[1] * D_DiffCoeff[1,ny] + area[2] * D_DiffCoeff[i,ny-1]) / Tarea 
    end
    MDnp = sum(DT2np)
    MDsp = sum(DT2sp) 

    GCnp = geom * MDnp + B_coeff + 2 * C_HeatCapacity[1,1] * NT     # north pole 
    GCsp = geom * MDsp + B_coeff + 2 * C_HeatCapacity[1,ny] * NT    # south pole

    for i=1:nx
        #North pole
        row_idx = i
        A[row_idx,row_idx] = GCnp
        for ii=1:nx
            A[row_idx,nx+ii] = - geom * DT2np[ii]
        end
        
        #South pole
        row_idx = dof + 1 - i
        A[row_idx,row_idx] = GCsp
        for ii=1:nx
            A[row_idx,dof-2*nx+ii] = - geom * DT2sp[ii]
        end
    end
    return A
end

function UpdateRHS!(RHS, mesh, NT, time_step, Temp, model, LastRHS)
    # ACHTUNG!!: Here we assume that all nodes at each pole have the same model parameters
    @unpack nx,ny = mesh
    @unpack C_HeatCapacity, SolarForcing, A_coeff = model
    for j=1:ny
        for i=1:nx
            row_idx = index1d(i,j,nx)

            RHS[row_idx] = 4 * C_HeatCapacity[i,j] * Temp[row_idx] * NT  - LastRHS[row_idx] + SolarForcing[i,j,time_step] #- 2 * A_coeff
            if (time_step == 1)
                RHS[row_idx] += SolarForcing[i,j,NT]
            else
                RHS[row_idx] += SolarForcing[i,j,time_step-1]
            end
        end
    end
    LastRHS .= RHS
end