# Network JSON Format

JSON Network format consists of three field, each one of them is array

- `inputs` - list of network input tensors
- `outputs` - list of network output tensors
- `operators` - list of operators executed in graph

## Inputs

Input is object that carries following fields:

- `name` - tensor name string
- `shape` - tensor shape list of integers
- `dtype` - type of tensor string, default is "float"

For example:

    "inputs": [
        {
            "shape": [ 64, 1, 28, 28 ],
            "name":  "data"
        },
        {
            "shape": [ 64 ],
            "name":  "label",
            "dtype": "int"
        }
    ],


## Outputs

Outputs are either string representing output tensor name or an object with fields `name` with string value as tensor name and `loss_weight` for weight for loss.

Note: if tensor name starts with `loss` it is considered a loss and back propagation goes from it. Default loss weight is 1.0. If `loss_weight` is provided than the tensor considered as loss and it will participate in back propagation.

For example

    "outputs" : [ 
        "prob", 
        { "name" : "cross_entropy_loss", "loss_weight": 1.0 }
    ]

## Operators

Operators is list of operators executed during forward and back-propagation in the order provided. They create edges between nodes. The graph must be acyclic with exception of in-place operators (i.e. it may be self edge)

Each operator has following fields:

- `name` - unique name of operator, string
- `type` - type of operation, string, for example "Activation"
- `inputs` - list of input tensors - must be either outputs of one of previous operators or one of inputs - list of strings
- `outputs` - list of generated tensors, can be same as input for in-place operations - list of strings. 
- `frozen` - boolean flag that marks the operator as not-participating in gradient descend, for example for transfer learning. Default is `false`
- `options` - object operation specific parameters

For example:

    {
        "name": "fc2",
        "type": "InnerProduct",
        "inputs": ["fc1"],
        "outputs": ["fc2"],
        "options": {"outputs": 10}
    }

## Supported Operators and Options

### Softmax and SoftmaxWithLoss

No parameters at this point

### Activation

Parameters:

- `activation` - string, one of standard activation names

### Elementwise


Parameters:

- `operation` - string, one of `sum` for `ax + by`, `prod` - for `ax * by` , `max` for `max(ax,by)` where, `x` and `y` are input tensors, `a` and `b` are coefficients - default is `sum` 
- `coef1` - scale for 1st input, number default 1
- `coef2` - scale for 2nd input, number default 1
- `activation` - string one of standard activation names

### Pooling2D

Parameters

- `mode` - string, one of `max` and `avg`, default is `max`
- `kernel` - integer or list of two integers, pooling kernel size.
- `stride` - integer or list of two integers, pooling stride, default 1
- `pad`  - integer or list of two integer, padding, default 0
- `count_include_pad` - boolean calculate average over padded area as well, default false

Note: kernel, stride and pad can be either single number for symmetric values or pair of integers, 1st for height dimension and second for width

### GlobalPooling

Parameters

- `mode` - string, one of `max` and `avg`, default is `max`

### InnerProduct

Parameters

- `outputs` - integer - number of output features
- `inputs` - integer - number of input features, can be deduced automatically
- `bias` - boolean - apply bias, default true
- `activation` - string, optional, one of standard activation names

### Convolution2D

Parameters:

- `channels_out` - integer, number of output channels/features
- `channels_in` - number of input channels, can be deduced automatically
- `groups` - number of convolution groups, integer, default 1
- `bias` - boolean - apply bias, default true
- `kernel` - integer or list of two integers, convolution kernel size.
- `stride` - integer or list of two integers, convolution stride, default 1
- `pad`  - integer or list of two integer, padding, default 0
- `dilate`  - integer or list of two integer, dilation, default 1

Note: kernel, stride, dilate and pad can be either single number for symmetric values or pair of integers, 1st for height dimension and second for width

### TransposedConvolution2D

Parameters:

- `channels_out` - integer, number of output channels/features
- `channels_in` - number of input channels, can be deduced automatically
- `groups` - number of convolution groups, integer, default 1
- `bias` - boolean - apply bias, default true
- `kernel` - integer or list of two integers, convolution kernel size.
- `stride` - integer or list of two integers, convolution stride, default 1
- `pad`  - integer or list of two integer, padding, default 0
- `output_pad`  - integer or list of two integer, padding of output in order to solve ambiguity if "input" size due to strides, default 0
- `dilate`  - integer or list of two integer, dilation, default 1

Note: kernel, stride, dilate, pad and output\_pad can be either single number for symmetric values or pair of integers, 1st for height dimension and second for width


### BatchNorm2D

Parameters

- `features` - integer number of input features, can be automatically deduced
- `eps` - floating point value, default 1e-5, epsilon for batch normalization `y = x / sqrt( var + eps)`
- `momentum` - floating point value, default 0.1, portion of the newly calculated mean/variance in running sums: 
  `running_sum := (1-momentum)*running_sum + momentum * batch_sum`
- `affine` - boolean, default true, apply additional trainable gamma scale and beta offset after normalization
- `use_global_stats` - use previously calculated mean/variance instead of calculating them per-batch and updating running sums. Useful for freezing layer, default false. Note: for testing it is "always true"

### Concat

Parameters

- `dim` - concatenate input tensors over dimension dim, default 1

### Slice

Parameters

- `dim` - slice input tensor over dimension dim, default 1
- `begin` - begin index of slice, default 0
- `end` - end index of slice, default end 

For example: `{ "begin":1, "end":2","dim":1 }` - slice green channel

## Standard Activations

Following are standard activation names: `relu`, `sigmoid`, `tanh`, `relu6`, `identity`

## Example MNIST MLP Network

This is an example of a simple MLP network for mnist training

    {
        "inputs": [
            { 
                "shape": [ 64,1,28,28 ],
                "name": "data"
            },
            {
                "shape": [64],
                "name": "label",
                "dtype" : "int"
            }
        ],
        "outputs" : [ 
            "prob", "loss" 
        ],
        "operators": [
            {
                "name": "fc1",
                "type": "InnerProduct",
                "inputs": [ "data" ],
                "outputs": [ "fc1" ],
                "options": {
                    "outputs": 256,
                    "activation": "relu"
                }
            },
            {
                "name": "fc2",
                "type": "InnerProduct",
                "inputs": ["fc1" ],
                "outputs": [ "fc2" ],
                "options": {
                    "outputs": 10
                }
            },
            {
                "name": "prob",
                "type": "Softmax",
                "inputs": ["fc2"],
                "outputs": ["prob"]
            },
            {
                "name": "loss",
                "type": "SoftmaxWithLoss",
                "inputs": ["fc2","label"],
                "outputs": ["loss"]
            }
        ]
    }
