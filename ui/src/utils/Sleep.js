/**
 * sleep time, in milliseconds
 */
export default function sleep(time) {
    return new Promise((resolve) => setTimeout(resolve, time));
}