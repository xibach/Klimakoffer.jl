
struct Discretization{LType, UType, PType}
  L::LType
  U::UType
  p::PType
  NT::Int64
  mesh::Mesh
  model::Model
  AnnualTemp::Array{Float64, 2}
  RHS::Vector{Float64}
  LastRHS::Vector{Float64}
end


function Discretization(mesh, model, NT)
    A = ComputeMatrix(mesh,NT,model)
    LUdec = lu(A)
    L = sparse(LUdec.L)
    U = sparse(LUdec.U)

    AnnualTemp = fill(5.0, mesh.dof, NT) # Magic initialization
    RHS     = zeros(mesh.dof)  # TODO: The EBM Fortran code initializes the RHS to zero... Maybe we want to initialize it differently
    LastRHS = zeros(mesh.dof)

    Discretization(L, U, LUdec.p, NT, mesh, model, AnnualTemp, RHS, LastRHS)
end