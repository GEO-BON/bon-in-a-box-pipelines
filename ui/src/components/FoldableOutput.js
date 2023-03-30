import React, { useRef, useEffect, useContext, useState } from 'react';

export const RenderContext = React.createContext();

export function createContext(activeRenderer, setActiveRenderer) {
    return { 
        active: activeRenderer,
        toggleVisibility: (componentId) => setActiveRenderer(activeRenderer === componentId ? null : componentId)
    }
}

export function FoldableOutputWithContext({className, title, componentId, inline, inlineCollapsed, children, keepWhenHidden}) {
    const renderContext = useContext(RenderContext);
    let active = renderContext.active === componentId;

    return <FoldableOutputInternal toggle={() => renderContext.toggleVisibility(componentId)} active={active}
        className={className} title={title} inline={inline} inlineCollapsed={inlineCollapsed} children={children} keepWhenHidden={keepWhenHidden}/>
}

export function FoldableOutput({className, title, inline, inlineCollapsed, children, isActive, keepWhenHidden}) {
    const [active, setActive] = useState(false)
    useEffect(() => {
        setActive(isActive)
    }, [isActive]);

    return <FoldableOutputInternal toggle={() => setActive(prev => !prev)} active={active}
        className={className} title={title} inline={inline} inlineCollapsed={inlineCollapsed} children={children} keepWhenHidden={keepWhenHidden} />
}

function FoldableOutputInternal({toggle, active, className, title, inline, inlineCollapsed, children, keepWhenHidden}) {
    const titleRef = useRef(null);

    useEffect(() => {
        if (active) {
            titleRef.current.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
    }, [active]);

    return <div className={className}>
        <div className="outputTitle">
            <h3 ref={titleRef} onClick={toggle} className="clickable">
                {active ? <b>–</b> : <b>+</b>} {title}
            </h3>
            {inline}
            {!active && inlineCollapsed}
        </div>

       
        {keepWhenHidden ?  // If we need to keep it when hidden (such as not to lose the content of a form), then we se height to 0 when folded.
            <div className="outputContent" style={{
                height: active ? "auto" : "0px",
                overflow: 'hidden'
            }}>
                {children}
            </div>

            : active &&
            <div className="outputContent">
                {children}
            </div>
        }
    </div>
}
