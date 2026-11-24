(() => {
  "use strict";

  const formulario = document.getElementById("filtros-plano");
  const panel = document.getElementById("detalle-hilera");
  const hileras = Array.from(
    document.querySelectorAll(".explorador-hilera")
  );

  // Aplicar los filtros al cambiar un campo.
  formulario?.addEventListener("change", (evento) => {
    if (evento.target.matches("select, input")) {
      formulario.requestSubmit();
    }
  });

  if (!panel || !hileras.length) return;

  function seleccionarHilera(boton) {
    const plantilla = document.getElementById(boton.dataset.detalle);
    if (!(plantilla instanceof HTMLTemplateElement)) return;

    hileras.forEach((hilera) => {
      hilera.setAttribute(
        "aria-pressed",
        String(hilera === boton)
      );
    });

    panel.replaceChildren(plantilla.content.cloneNode(true));
  }

  hileras.forEach((boton) => {
    boton.addEventListener("click", () => {
      seleccionarHilera(boton);
    });
  });

  // Respetar enlaces que apunten a una hilera, por ejemplo #H8.
  const hileraInicial = hileras.find(
    (hilera) => `#${hilera.id}` === window.location.hash
  ) || hileras[0];

  seleccionarHilera(hileraInicial);
})();