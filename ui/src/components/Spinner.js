import spinnerImg from "../img/spinner.svg";

export function Spinner(){
    return <img src={spinnerImg} className="spinner" alt="Spinner" />
}

export function InlineSpinner(){
    return <img src={spinnerImg} className="spinner-inline" alt="Spinner" />
}