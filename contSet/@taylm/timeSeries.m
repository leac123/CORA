function [reach, rs] = timeSeries(x, f, h, T, optns)
    N = ceil(T / h);
    reach = cell(N, 2);
    t = 0.0;
    i = 0;
    while t < T
        [flowpipe, x] = timeStep(x, f, h, optns, i);
        t = t + h
        w = max(arrayfun(@(x) rad(x.remainder), x))
        
        if mod(i, optns.zonotope_enclosure_mod) == 0 && 0
            x = order_1(x);
        end

        if mod(i, optns.shrinking_mod) == 0
            try
                tic
                x = shrink_wrap(x, optns.shrink_wrap_options);
                disp(['Shrink Wrap:', num2str(toc), ' s'])
            catch M
                disp('Catch')
                disp(M)
                tic
                wrap = parallelotope_wrap(x);
                x;
                disp(['Parallelotope Wrap:', num2str(toc), ' s'])
                if interval(wrap) <= optns.parallelotope_factor * interval(x)
                    x = wrap;
                elseif min(rad(interval(x))) >= 1
                    disp('Man, they are growing so fast')
                    break
                else
                    disp('No Parallelotope!')
                end
            end
        end
        i = i + 1;
        reach{i}{1} = x;
        reach{i}{2} = flowpipe;
    end
    rs = i;
end

function [flowpipe, final] = timeStep(x, f, h, optns, i)
    flowpipe = certify_step(f, x, h, optns);
    % TODO: ensure timestep is included in [0, h]
    if optns.timedependency == 1 && mod(i, optns.dt_mod) == 0
        x0 = arrayfun(@getCoef, center(x));
        h2 = 0.5 * h;
        Dr = approxReturnTimeDerivative(f, x0, h2);
        [c, nrml] = normalHyperplaneAtStep(f, x0, h2);

        % samples
        names = names_of(x);
        [~, nnames] = size(names);
        ranges = repmat({-1:0.1:1}, size(names));
        outputs = cell(size(ranges));
        [outputs{:}] = ndgrid(ranges{:});
        [n, m] = size(outputs{1, 1});
        ps = zeros(n * m, nnames);
        for i = 1:n
            for j = 1:m
                for v = 1:nnames
                    pv = outputs{1, v};
                    ps((i - 1) * m + j, v) = pv(i, j);
                end
            end
        end
        explanatory = ps;
        response=zeros(n*m, 1);
        for i = 1:n*m
            sample = arrayfun(@(v) explanatory(i, v), (1:nnames));
            samplepoint = point_eval(x, names, sample);
            response(i, 1) = returnTime(f, samplepoint, c, nrml, h);
        end
        F_fitted = nlinfit(explanatory,response,@templatePoly,[0, Dr, 0, 0, 0])
        arg(1, 1) = x(1,1);
        arg(1, 2) = x(2,1);
        arg(1, 1).remainder = interval(0, 0);
        arg(1, 2).remainder = interval(0, 0);
        timestep = 2 * templatePoly(F_fitted, arg) / h - 1
%       timestep = 1 + 2 * (x - c) * Dr / h;
% s on [-1; 1]
% t on [0; h]
% t = (s + 1)*h/2
% s = 2*t/h - 1
% xwr = set_remainders(x, repmat(interval(0,0), size(x)))
%       timestep = Dr * (xwr - c) / h % checked, this is perfectly right!
        itstp = interval(timestep);
        if interval(timestep) <= interval(-1, 1)
        else
            error ('The time is too wrong')
        end
    else
        timestep = taylm(interval(1, 1), x(1).max_order);
    end
    
    flowpipe;
    timestep;
    final = horner(flowpipe, {'t'}, timestep );
    final
end
