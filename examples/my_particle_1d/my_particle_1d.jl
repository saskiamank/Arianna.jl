# This is supposed to be an exact copy of the example for a 1d particle, so I can pratice coding it 

# First of all I need to include all the necessary packages
using Arianna                       # Arianna package 
using Arianna.PolicyGuided 
using Random                        # standard julia package for random numbers 
using Distributions                 # standard julia package to generate probability distributions 
using ComponentArrays               # julia package to handle arrays of components 

## first of all I need to define a system 
# I will define my particle first as a mutable struct 

mutable struct Particle{T<:AbstractFloat} <: AriannaSystem
    # particle is a subtype of AriannaSystem
    x::T        # defines the position of the particle 
    beta::T     # defines the inverse temperature 
    e::T        # defines the energy of the particle
    # this struct gets an inner constructor, automatically calculating the energy 
    # I use new{} which can only be used in inner constructors, to create a new instance of the struct
    function Particle(x::T, beta::T) where {T<:AbstractFloat}
        return new{}(x, beta, potential(x)) 
        # the energy is automatically calculated by potential 
    end 
end 

# Now define my system to be the Particle, I just defined before 
System(x, beta) = Particle(x, beta) # this is a constructor for the system, it takes x and beta as input and returns a Particle instance

# Arianna provides a generic method to calculate the unnormalised log target density, 
# but I need to define how it is determined in my case, 
# so in the case that the second argument is a Particly, 
# where I use a simple Boltzmann distribution 
function Arianna.unnormalised_log_target_density(energy, system::Particle)
    return system.beta * energy 
end 
# by using Arianna.function I make clear that I am not defining a new function 
# but using the exsiting one provided by Arianna



## ---------------------------------------
# Now that I have my system defined, I need to define the Actions 
# this includes specifying the action and its parameters, 
# specifyint how the action is actually performed
# the probability of sampling the action 
# and the probability of proposing the action 

# create the action 
mutable struct Displacement(T<:AbstractFloat) <: Action 
    delta :: T 
end 

# create function to perform action 

function Arianna.perform_action!(system::Particle, action::Displacement)
    e1 = system.e
    system.x += action.delta
    system.e = potential(system.x)
    return (e1, system.beta), (system.e, system.beta)
end 

## we also need a function to revert the action 

function Arianna.revert_action!(system::Particle, action::Displacment)
    action.delta = -action.delta
end 



#-----------------------------------------
# Now I have to set up my policies, which means first of all I am gonna create a struct for a policy 
# and then implement the functions I need for it: 
# each policy needs a sample_action! function which defines how the action is sampled 
# (for the displacement action the displacement vector is sampled, and I want to sample it from a uniform distribtion)
# then I also need a log_proposal_density function, which specifies the probability of proposing the action 

# this one will not be mutable because it is static
struct StandardGaussian <: Policy 
end 

# define a function to setup a standard parameter for the StandardGaussian
function setup_parameters(::StandardGaussian) 
    return ComponentArray(sigma = 1)
end 

# my function sample_action needs to depend on the action, the policy and the system, and then it needs to take 
# parameters for the Policy as well as a random seed because there is some random numbers involved
function Arianna.sample_action!(action::Displacement, ::StandardGaussian, parameters, ::Particle, rng)
    # now the function returns nothing, it just defines the actual parameter of the action 
    # here I want to draw the actual length of the displacement from a Gaussian with zero mean and the variance specified in parameters.sigma
    # zero(action.delta) produces a zero of the same type as action.delta, rand(rng, (Normal(mean, sigma))) draws a random number from 
    # a normal distribution with mean and variance, with the random number generator rng 
    action.delta = rand(rng, Normal(zero(action.delta), parameters.sigma))
    return nothing 
end 

# now I also need a function that actually gives the log of the probability of drawing the displacement I drew with sample action 
# the function basically defines the log of the probability distribution I use in sample_action 
# so this function just returns the log of a normal distribution 
function Arianna.log_proposal_density(action::Displacement, ::StandardGaussian, parameters, ::Particle)
    return -0.5log(2*pi*parameters.sigma^2) - (action.delta)^2/(2parameters.sigma^2)
end 

# ------------------------
# repeat for a uniform distribution 

struct StandardUniform <: Policy 
end 

function setup_parameters(::StandardUniform)
    return ComponentArray(l=1.0)
end 

# Draw a random displacement between -l/2 and l/2 ([-l/2;l/2)) from a uniform distribution and set the action 
# property delta to that displacement 
function Arianna.sample_action!(action::Displacement, ::StandardUniform, parameters, ::Particle, rng)
    action.delta = (rand(rng) - (1/2)) * parameters.l 
    return nothing 
end 


# Define a normalized uniform distribution 
function Arianna.log_proposal_density(action::Displacement, ::StandardUniform, parameters, ::Particle)
    return - log(parameters.l)
end 

#------------------
# Now I should have defined all important functions, I can now test if everything is implemented
# To check if all required functions have been implemented, you can run Arianna.Linter.run_linter("path/to/your/folder/or/file").


