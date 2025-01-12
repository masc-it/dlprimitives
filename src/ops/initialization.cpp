#include <dlprim/ops/initialization.hpp>
#include <dlprim/core/common.hpp>
#include <dlprim/random.hpp>
#include <string.h>
#include <cmath>

namespace dlprim {

void set_to_zero(Context &ctx,ExecutionContext const &e,Tensor &t)
{
    if(ctx.is_cpu_context()) {
        memset(t.host_data(),0,t.memory_size());
    }
    else {
       core::fill_tensor(ctx,e,t,0);
    }
}

namespace {
    template<typename T>
    void fill_value(Tensor &t,T v)
    {
        T *p= t.data<T>();
        size_t size = t.shape().total_size();
        for(size_t i=0;i<size;i++)
            p[i] = v;
    }
}

void set_to_constant(Context &ctx,ExecutionContext const &e,Tensor &t,double value)
{
    if(ctx.is_cpu_context()) {
        switch(t.dtype()) {
        case float_data: fill_value<float>(t,static_cast<float>(value)); break;
        case int32_data: fill_value<int>(t,static_cast<float>(value)); break;
        default:
            throw NotImplementedError("setting value fortype" + data_type_to_string(t.dtype()));
        }
    }
    else {
        core::fill_tensor(ctx,e,t,value);
    }
}


template<typename DistConverter>
void cpu_random_set(Tensor &t,RandomState::seed_type seed,RandomState::sequence_type seq,DistConverter cvt)
{
    DLPRIM_CHECK(t.dtype() == float_data);
    float *ptr = t.data<float>();
    size_t total = t.shape().total_size();
    size_t rounds = (total + philox::result_items - 1) / philox::result_items;
    for(size_t i=0;i<rounds;i++) {
        auto result = philox::calculate_float(seed,seq + i);
        cvt.convert(result);
        for(int j=0;j<philox::result_items;j++) {
            if(i*philox::result_items +j < total)
                *ptr++ = result[j];
        }
    }
}

class UrandomConverter {
public:
    UrandomConverter(float min,float max)
    {
        scale_ = (max-min);
        offset_ = min;
    }
    template<typename T>
    void convert(T &vec)
    {
        for(auto &val : vec) {
            val = val * scale_ + offset_;
        }
    }
    float scale_,offset_;
};

class NormalConverter {
public:
    NormalConverter(float mu,float sigma)
    {
        mu_ = mu;
        sigma_ = sigma;
    }
    void convert(philox::float_result_type &f)
    {
        convert_pair(f[0],f[1]);
        convert_pair(f[2],f[3]);
    }
private:
    void convert_pair(float &r1,float &r2)
    {
        float scale = std::sqrt(-2.0f*std::log(1.0f - r1)) * sigma_;
        ///                                     r1 in [0, 1)
        float angle = (2.0f*3.1415926535f)*r2;
        r1 = scale*std::cos(angle) + mu_;
        r2 = scale*std::sin(angle) + mu_;
    }
    float mu_,sigma_;
};

void get_seed_seq(size_t total,RandomState &state,RandomState::seed_type &seed,RandomState::sequence_type &seq)
{
    size_t rounds = (total +  philox::result_items - 1) / philox::result_items;
    seed = state.seed();
    seq  = state.sequence_bump(rounds);

}
void set_to_urandom(Context &ctx,ExecutionContext const &e,Tensor &t,RandomState &state,float minv,float maxv)
{
    RandomState::seed_type seed;
    RandomState::sequence_type seq;
    get_seed_seq(t.shape().total_size(),state,seed,seq);
    if(ctx.is_cpu_context()) {
        UrandomConverter c(minv,maxv);
        cpu_random_set(t,seed,seq,c);
    }
    else {
        core::fill_random(ctx,e,t,seed,seq,core::rnd_uniform,minv,maxv);
    }
}

///
/// set t values to normal distribution with mean and sigma), seed is updated
///
void set_to_normal(Context &ctx,ExecutionContext const &e,Tensor &t,RandomState &state,float mean,float sigma)
{
    RandomState::seed_type seed;
    RandomState::sequence_type seq;
    get_seed_seq(t.shape().total_size(),state,seed,seq);
    if(ctx.is_cpu_context()) {
        NormalConverter c(mean,sigma);
        cpu_random_set(t,seed,seq,c);
    }
    else {
        core::fill_random(ctx,e,t,seed,seq,core::rnd_normal,mean,sigma);
    }
}

} //  dlprim

