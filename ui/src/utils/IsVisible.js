// From https://htmldom.dev/check-if-an-element-is-visible-in-a-scrollable-container/
export const isVisible = function (ele, container) {
  const { bottom, height, top } = ele.getBoundingClientRect();
  const containerRect = container.getBoundingClientRect();

  return top <= containerRect.top ? containerRect.top - top <= height : bottom - containerRect.bottom <= height;
};