import React, {useState, lazy, Suspense} from 'react';
import { createRoot } from 'react-dom/client';
import './index.css';
import reportWebVitals from './reportWebVitals';
import {
  BrowserRouter,
  Routes,
  Route,
  useLocation,
} from "react-router-dom";


import { PipelinePage } from "./components/PipelinePage";
import StepChooser from "./components/PipelineEditor/StepChooser";
import { Layout } from './Layout.js';
import Versions from './components/Versions';
import { Spinner } from './components/Spinner';
const PipelineEditor = lazy(() => import("./components/PipelineEditor/PipelineEditor"));

function NotFound() {
  const location = useLocation()
  return <main style={{ padding: "1rem" }}>
    <h2>404 - Page not found</h2>
    <p>{location.pathname}</p>
    <p>Lost in the wilderness?</p>
  </main>
}

function App() {
  const [popupContent, setPopupContent] = useState();

  return <BrowserRouter>
    <Routes>
      <Route path="/" element={<Layout />} />

      <Route path="script-form/:pipeline?/:runHash?" element={
        <Layout right={<PipelinePage runType="script" />} />
      } />
      
      <Route path="pipeline-form/:pipeline?/:runHash?" element={
        <Layout right={<PipelinePage runType="pipeline" />} />
      } />

      <Route path="pipeline-editor" element={
        <Layout left={<StepChooser popupContent={popupContent} setPopupContent={setPopupContent} />}
          right={
            <Suspense fallback={<Spinner />}>
              <PipelineEditor />
            </Suspense>
          }
          popupContent={popupContent}
          setPopupContent={setPopupContent} />
      } />

      <Route path="versions" element={
        <Layout right={<Versions />} />
      } />

      <Route path="*" element={
        <Layout right={<NotFound />} />
      } />

    </Routes>
  </BrowserRouter>
}

const root = createRoot(document.getElementById('root'));
root.render(<App />);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
