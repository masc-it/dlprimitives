#include <dlprim/definitions.hpp>

namespace dlprim {
    StandardActivations activation_from_name(std::string const &name)
    {
        if(name == "identity")
            return StandardActivations::identity;
        if(name == "relu")
            return StandardActivations::relu;
        if(name == "tanh")
            return StandardActivations::tanh;
        if(name == "sigmoid")
            return StandardActivations::sigmoid;
        if(name == "relu6")
            return StandardActivations::relu6;
        throw ValidationError("Invalid cativation name:" + name);
    }
    char const *activation_to_name(StandardActivations act)
    {
        switch(act) {
        case StandardActivations::identity:
            return "identity";
        case StandardActivations::relu:
            return "relu";
        case StandardActivations::tanh:
            return "tanh";
        case StandardActivations::sigmoid:
            return "sigmoid";
        case StandardActivations::relu6:
            return "relu6";
        }
        throw ValidationError("Internal error invalid cativation");
    }
} // dlprim


