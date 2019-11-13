

"""
Quick thin wrapper around the Knet RNN implementation. Ideally would like to bring
it more inline with other layers, so Photon creates the weights and use Knet
as a stateless function.

The Knet API:

```julia
RNN(inputSize, hiddenSize;
             h=nothing, c=nothing,
             handle=gethandle(),
             numLayers=1,
             dropout=0.0,
             skipInput=false,     # CUDNN_LINEAR_INPUT = 0, CUDNN_SKIP_INPUT = 1
             bidirectional=false, # CUDNN_UNIDIRECTIONAL = 0, CUDNN_BIDIRECTIONAL = 1
             rnnType=:lstm,       # CUDNN_RNN_RELU = 0, CUDNN_RNN_TANH = 1, CUDNN_LSTM = 2, CUDNN_GRU = 3
             dataType=Float32,    # CUDNN_DATA_FLOAT  = 0, CUDNN_DATA_DOUBLE = 1, CUDNN_DATA_HALF   = 2
             algo=0,              # CUDNN_RNN_ALGO_STANDARD = 0, CUDNN_RNN_ALGO_PERSIST_STATIC = 1, CUDNN_RNN_ALGO_PERSIST_DYNAMIC = 2
             seed=0,              # seed=0 for random init, positive integer for replicability
             winit=xavier,
             binit=zeros,
             finit=ones,        # forget bias for lstm
             usegpu=(gpu()>=0),
             )
```
"""


mutable struct Recurrent <: LazyLayer
    hidden_size::Int
    num_layers::Int
    ops
    built::Bool
    last_only::Bool
    init::NamedTuple
    mode
end


function build(l::Recurrent, shape::Tuple)
    inputSize = shape[1]

    l.ops = Knet.RNN(
        inputSize,
        l.hidden_size,
        numLayers = l.num_layers,
        dataType = ctx.dtype,
        usegpu = is_on_gpu(),
        rnnType = l.mode,
        winit = l.init.w,
        binit = l.init.b,
        finit = l.init.f,
    )
end

function call(layer::Recurrent, X)
    output = layer.ops(X)
    if layer.last_only
        output[:, end, :]
    else
        output
    end
end

"""
A simple RNN layer.
"""
function RNN(
    hidden_size,
    num_layers = 1;
    activation=:tanh,
    dropout = 0.0,
    bidirectional = false,
    last_only = true,
    initw = Knet.xavier,
    initb = zeros,
    initf = ones
)
    @assert activation in [:tanh, :relu] "Only :tanh and :relu are supported"
    Recurrent(hidden_size, num_layers, undef, false, last_only,
    (w=initw, b=initb, f=initf), activation)
end

"""
Create a LSTM layer.

Examples:
=========

    layer = LSTM(50)

"""
function LSTM(
    hidden_size,
    num_layers = 1;
    dropout = 0.0,
    bidirectional = false,
    last_only = true,
    initw = Knet.xavier,
    initb = zeros,
    initf = ones
)
    Recurrent(hidden_size, num_layers, undef, false, last_only,
    (w=initw, b=initb, f=initf), :lstm)
end


"""
Create a GRU layer

Examples:
=========

    layer = GRU(50)

"""
function GRU(
    hidden_size,
    num_layers = 1;
    dropout = 0.0,
    bidirectional = false,
    last_only = true,
    initw = Knet.xavier,
    initb = zeros,
    initf = ones
)
    Recurrent(hidden_size, num_layers, undef, false, last_only,
    (w=initw, b=initb, f=initf), :gru)
end


@debug "Loaded Recurrent modules"
