const LEFT_LOBE = "M200,100 C170,40 40,30 40,100 C40,170 170,160 200,100";
const RIGHT_LOBE = "M200,100 C230,40 360,30 360,100 C360,170 230,160 200,100";

type Props = {
  className?: string;
  /** Boucle d'une seule couleur, sans libellés (filigrane). */
  watermark?: boolean;
};

export default function DevOpsLoop({ className, watermark = false }: Props) {
  if (watermark) {
    return (
      <svg className={className} viewBox="0 0 400 200" aria-hidden="true">
        <path
          d={`${RIGHT_LOBE} ${LEFT_LOBE.replace("M200,100 ", "")}`}
          fill="none"
          stroke="#fff"
          strokeWidth={30}
          strokeLinecap="round"
        />
      </svg>
    );
  }

  return (
    <svg
      className={className}
      viewBox="0 0 400 200"
      role="img"
      aria-label="Boucle DevOps : Dev et Ops"
    >
      <path d={RIGHT_LOBE} fill="none" stroke="#2B2F38" strokeWidth={30} strokeLinecap="round" />
      <path d={LEFT_LOBE} fill="none" stroke="#1F5FD1" strokeWidth={30} strokeLinecap="round" />
      <text x={105} y={111} textAnchor="middle">Dev</text>
      <text x={295} y={111} textAnchor="middle">Ops</text>
    </svg>
  );
}
